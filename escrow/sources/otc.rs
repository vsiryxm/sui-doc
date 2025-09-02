module otc::otc {
    /*************************************************
     * OTC 部分成交订单撮合简化示例
     *
     * 设计目标：
     *  1. 每个订单 = 独立对象 (Order)，持有尚未卖出的 base 资产 Coin<TBase>
     *  2. 部分成交：taker 提供一部分 quote 资产，按价格换取 base
     *  3. 并发友好：不同订单彼此独立；共享对象只做一个自增序列
     *  4. 取消：只有 maker（或其持有的 CancelCap）能取消
     *
     * 泛型参数：
     *  TBase  - 被卖出的资产类型（例如自定义 USDC）
     *  TQuote - 用来支付的资产类型（例如 SUI）
     *
     * 注意：
     *  - Coin<T> 是 Sui 框架里对任意代币类型 T 的同质化资产包装
     *  - 这里未实现价格撮合（撮多个订单）；taker 必须指定要填的单
     *************************************************/

    use sui::tx_context::{TxContext, sender};
    use sui::clock::{Self as clock, Clock};
    use sui::object;
    use sui::transfer;
    use sui::coin::{Self as coin, Coin, split, join, value};
    use sui::event;

    /**********************
     * 事件 (Event) 定义
     * 说明：事件用于链下索引器抓取，构建订单簿视图
     * id: 订单对象地址（object::id_address(&order.id)）
     **********************/
    struct OrderCreated has copy, drop {
        id: address,      // 新订单对象地址
        seq: u64,         // 时间优先序列号（从 OrderBook.next_seq 取）
        base: u64,        // 初始挂单 base 数量
        price_n: u64,     // 价格分子
        price_d: u64,     // 价格分母
        expiry: u64       // 过期时间（毫秒时间戳）
    }

    struct OrderFilled has copy, drop {
        id: address,          // 被成交的订单地址
        filled_base: u64,     // 此次成交 base 数量
        filled_quote: u64,    // 此次成交 quote 数量
        remaining: u64        // 剩余 base 数量
    }

    struct OrderCanceled has copy, drop {
        id: address,      // 被取消订单地址
        remaining: u64    // 取消时剩余 base 数量（已经返还）
    }

    /**********************
     * OrderBook 共享对象（轻量）
     * 作用：
     *  - 保存一个自增序列 next_seq，用于给订单时间优先排序
     *  - 保存协议级别 fee_bps（示例里 fill_order 暂未引用，可自行扩展）
     *
     * 备注：
     *  - 创建后如果你希望多地址能调用 create_order，需要将该对象转为 shared：
     *      transfer::share_object(book);
     *  - 共享对象在函数参数中使用 &mut 引用时，会参与对象级冲突检测
     **********************/
    struct OrderBook<TBase, TQuote> has key {
        id: UID,       // 对象唯一标识
        next_seq: u64, // 下一个可用序列号（创建订单时自增）
        fee_bps: u64,  // 协议费率（万分比），示例未完全串联
    }

    /**********************
     * CancelCap 取消权限对象
     * 作用：
     *  - 只有持有对应 order_id 且 maker 匹配的 CancelCap 才能调用 cancel
     * 设计理由：
     *  - 使用“拥有某种资源即具备权限”的 Move 模式
     *  - 避免只用地址判断（更清晰的权限转移/托管）
     **********************/
    struct CancelCap has key {
        id: UID,          // 唯一标识
        order_id: address,// 对应订单对象地址
        maker: address    // 订单创建者地址（冗余校验）
    }

    /**********************
     * Order 订单对象
     * 字段说明：
     *  - base_coin        实际持有的尚未卖出的 base 资产
     *  - base_remaining   剩余数量（理论上应与 base_coin 内部的 value 保持一致）
     *  - price_n/price_d  价格：一个 base 需要支付的 quote 数量 = ceil(base * n / d)
     *  - seq              时间优先序号（辅助链下排序；链上只读）
     *  - expiry           毫秒级过期时间戳（取自 Clock::timestamp_ms）
     *  - filled_base      累积成交 base 数
     *  - filled_quote     累积成交 quote 数
     *  - status           订单状态：
     *                       0 Open（未成交）
     *                       1 Partial（部分成交）
     *                       2 Filled（全部成交）
     *                       3 Canceled（被取消）
     *                       4 Expired（过期自动或惰性处理，这里尚未实现专门函数）
     **********************/
    struct Order<TBase, TQuote> has key {
        id: UID,
        maker: address,
        base_coin: Coin<TBase>,
        base_remaining: u64,
        price_n: u64,
        price_d: u64,
        seq: u64,
        expiry: u64,
        filled_base: u64,
        filled_quote: u64,
        status: u8,
    }

    /**********************
     * FeeVault 协议费金库
     *  - fees: 累积的 Quote 代币费用
     * 生产增强：
     *  - 可能需要另一个权限资源来提取费用
     **********************/
    struct FeeVault<TQuote> has key {
        id: UID,
        fees: Coin<TQuote>
    }

    /*************************************************
     * init
     * 目的：部署初期初始化一个 OrderBook + FeeVault
     *
     * 参数：
     *  - fee_bps           协议费率（万分比，例如 25 = 0.25%）
     *  - base_coin_zero    仅用于带入 TBase 类型（可用 0 值的 Coin<TBase> 传入）
     *  - quote_coin_zero   用于初始化 FeeVault 的 Coin<TQuote>（可为 0）
     *  - ctx               交易上下文
     *
     * 返回：
     *  - (OrderBook, FeeVault)
     *
     * 部署步骤（示意）：
     *  1. 调用 init 获得两个对象
     *  2. transfer::share_object(order_book) 使其成为 shared
     *  3. transfer::share_object(fee_vault)  或者仅管理员持有（看费策略）
     *************************************************/
    public fun init<TBase, TQuote>(
        fee_bps: u64,
        base_coin_zero: Coin<TBase>,
        quote_coin_zero: Coin<TQuote>,
        ctx: &mut TxContext
    ): (OrderBook<TBase,TQuote>, FeeVault<TQuote>) {
        // base_coin_zero 在此只为引入类型；真实可选择销毁或返回
        let (_phantom_uid, _unused_coin) = (object::new(ctx), base_coin_zero);
        let book = OrderBook {
            id: object::new(ctx),
            next_seq: 0,
            fee_bps
        };
        let fv = FeeVault {
            id: object::new(ctx),
            fees: quote_coin_zero
        };
        (book, fv)
    }

    /*************************************************
     * create_order
     * 目的：创建一个新的卖单（挂出 TBase，定价为 quote）
     *
     * 参数：
     *  - book        &mut OrderBook（需要 mutable，因为要自增 next_seq）
     *  - base_coin   Maker 想卖出的 Coin<TBase> 资产（全部先锁进订单）
     *  - price_n     价格分子（和 price_d 组合： 1 base 价格 = n/d quote）
     *  - price_d     价格分母（必须 > 0）
     *  - expiry      过期时间戳（毫秒），应 >= 当前时间
     *  - ctx         交易上下文（用于创建新对象）
     *
     * 返回：
     *  - (Order, CancelCap) 订单对象与对应取消权限
     *
     * 安全 & 设计要点：
     *  - base_amount = coin::value(&base_coin) 必须 > 0
     *  - seq 从 book.next_seq 取，再自增
     *  - 订单初始 status = 0 (Open)
     *  - 事件 OrderCreated 用于链下索引
     *************************************************/
    public entry fun create_order<TBase, TQuote>(
        book: &mut OrderBook<TBase,TQuote>,
        base_coin: Coin<TBase>,
        price_n: u64,
        price_d: u64,
        expiry: u64,
        ctx: &mut TxContext
    ): (Order<TBase,TQuote>, CancelCap) {
        assert!(price_d > 0, 0); // 简化错误码
        let maker = sender(ctx);
        let base_amount = value(&base_coin);
        assert!(base_amount > 0, 1);

        let seq = book.next_seq;
        book.next_seq = seq + 1;

        let order = Order {
            id: object::new(ctx),
            maker,
            base_coin,
            base_remaining: base_amount,
            price_n,
            price_d,
            seq,
            expiry,
            filled_base: 0,
            filled_quote: 0,
            status: 0
        };

        let cap = CancelCap {
            id: object::new(ctx),
            order_id: object::id_address(&order.id),
            maker
        };

        event::emit(OrderCreated {
            id: object::id_address(&order.id),
            seq,
            base: base_amount,
            price_n,
            price_d,
            expiry
        });

        (order, cap)
    }

    /*************************************************
     * fill_order
     * 目的：Taker 吃单（部分或全部），获得 base，支付 quote
     *
     * 参数：
     *  - order        &mut Order           要被填的订单对象引用（必须可变，因为要更新剩余）
     *  - pay_quote    Coin<TQuote>         Taker 准备支付的 quote 资产（可多于实际需要，剩余会退回）
     *  - desired_base u64                  Taker 想购买的 base 数量上限
     *  - fv           &mut FeeVault<TQuote>费用金库存放
     *  - clock        &Clock                用于校验订单未过期
     *  - ctx          &mut TxContext
     *
     * 流程概览：
     *  1. 校验状态与未过期
     *  2. 计算可成交 base = min(desired_base, order.base_remaining)
     *  3. 计算所需 quote = ceil(base * price_n / price_d)
     *  4. 从 pay_quote 分离出需要的 quote_for_maker
     *  5. 计算 fee => 放入 FeeVault
     *  6. 剩余净额 quote 转给 maker
     *  7. 从 order.base_coin split 出 base_for_taker => 转给 taker
     *  8. 更新字段 base_remaining / filled_xxx / status
     *  9. pay_quote 剩余退还
     * 10. 发出 OrderFilled 事件
     *
     * 注意：
     *  - 这里的 fee_bps 写死；真实项目应改为使用 book.fee_bps 或订单记录时缓存
     *  - 这里未处理订单被完全成交后再调用（status==2）的防御（已有断言）
     *************************************************/
    public entry fun fill_order<TBase, TQuote>(
        order: &mut Order<TBase,TQuote>,
        mut pay_quote: Coin<TQuote>,
        desired_base: u64,
        fv: &mut FeeVault<TQuote>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let now = clock::timestamp_ms(clock);
        assert!(now <= order.expiry, 10);                            // 未过期
        assert!(order.status == 0 || order.status == 1, 11);         // open 或 partial
        assert!(desired_base > 0, 12);

        // 可成交 base 数量（可能小于 taker 想要的）
        let can_base = if (desired_base <= order.base_remaining) { desired_base } else { order.base_remaining };

        // 计算需要的 quote 数量 = ceil(can_base * price_n / price_d)
        let need_quote_num = can_base * order.price_n;
        let need_quote = (need_quote_num + order.price_d - 1) / order.price_d;

        let available_quote = value(&pay_quote);
        assert!(available_quote >= need_quote, 13);                  // 支付能力足够

        // 从 pay_quote 中分离需要的部分
        let quote_for_maker = split(&mut pay_quote, need_quote);

        // 计算费用 (示例写死 20 bps = 0.20%)
        let fee_bps = 20;
        let gross = value(&quote_for_maker);
        let fee = (gross * fee_bps) / 10_000;

        // 拆出 fee
        if (fee > 0) {
            let fee_part = split(&mut (quote_for_maker), fee);
            // 累积到 FeeVault
            fv.fees = join(fv.fees, fee_part);
        }

        // 剩余净额给 maker
        transfer::transfer(quote_for_maker, order.maker);

        // 从订单内部的 base_coin 拆出成交部分
        let base_for_taker = split(&mut order.base_coin, can_base);

        // 更新订单内部统计
        order.base_remaining = order.base_remaining - can_base;
        order.filled_base = order.filled_base + can_base;
        order.filled_quote = order.filled_quote + need_quote;
        if (order.base_remaining == 0) {
            order.status = 2; // Filled
        } else {
            order.status = 1; // Partial
        }

        // 把 base 给 taker
        transfer::transfer(base_for_taker, sender(ctx));

        // 退还多余的 quote
        if (value(&pay_quote) > 0) {
            transfer::transfer(pay_quote, sender(ctx));
        }
        // 如果 value=0，会被自动销毁（空 Coin）

        event::emit(OrderFilled {
            id: object::id_address(&order.id),
            filled_base: can_base,
            filled_quote: need_quote,
            remaining: order.base_remaining
        });
    }

    /*************************************************
     * cancel
     * 目的：Maker 取消未完全成交的订单，取回剩余 base
     *
     * 参数：
     *  - order  Order 对象（by value 传入，函数结束后销毁）
     *  - cap    CancelCap（校验权限）
     *  - clock  &Clock（可用于将来扩展：比如过期后可被任意人取消；这里仅做权限校验）
     *  - ctx    &mut TxContext
     *
     * 流程：
     *  1. 校验 cap.order_id == order.id 且 cap.maker == order.maker
     *  2. 校验订单状态为 open 或 partial
     *  3. 剩余 base_coin 返还给 maker
     *  4. 发事件 OrderCanceled
     *  5. 销毁 CancelCap 与 Order
     *************************************************/
    public entry fun cancel<TBase,TQuote>(
        order: Order<TBase,TQuote>,
        cap: CancelCap,
        _clock: &Clock,          // 当前版本未使用，可留作扩展（超时取消）
        _ctx: &mut TxContext
    ) {
        assert!(cap.order_id == object::id_address(&order.id), 20);
        assert!(cap.maker == order.maker, 21);
        assert!(order.status == 0 || order.status == 1, 22); // 只能取消未完全成交的订单

        // 返还剩余 base；因为 base_coin 可能仍还有 base_remaining
        if (order.base_remaining > 0) {
            transfer::transfer(order.base_coin, order.maker);
        } else {
            // 如果刚好剩余 0，base_coin 也是 0；可直接丢弃。这里为了示例简单不区分。
        }

        event::emit(OrderCanceled {
            id: object::id_address(&order.id),
            remaining: order.base_remaining
        });

        // 销毁 CancelCap
        let CancelCap { id: cap_id, order_id: _, maker: _ } = cap;
        object::delete(cap_id);

        // 释放 Order（by-value）并销毁其 id
        let Order {
            id,
            maker: _,
            base_coin: _,
            base_remaining: _,
            price_n: _,
            price_d: _,
            seq: _,
            expiry: _,
            filled_base: _,
            filled_quote: _,
            status: _
        } = order;
        object::delete(id);
    }
}