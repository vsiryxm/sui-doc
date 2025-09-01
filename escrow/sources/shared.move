/// 基于共享对象的托管（escrow）示例，用于在无需受信任第三方的情况下进行对象的原子交换
///
/// 协议包含三阶段：
///
/// 1. 一方对他们的对象执行 `lock`，得到一个 `Locked` 对象和对应的 `Key`
///    如果另一方在第二阶段之前停滞，该方可通过 `unlock` 恢复其对象以保持活性（liveness）
///
/// 2. 另一方注册一个对外可见的、共享的 `Escrow` 对象
///    这实际上会在特定版本上锁定他们的对象，等待第一方完成交换第二方也可以请求将对象退回以保持活性
///
/// 3. 第一方将其锁定的对象和密钥发送给共享的 `Escrow` 对象
///    只要满足所有条件，交换便会完成：
///
/// 基于共享对象的托管（escrow）示例，用于在无需受信任第三方的情况下进行对象的原子交换
///
/// 协议包含三阶段：
///
/// 1. 一方对他们的对象执行 `lock`，得到一个 `Locked` 对象和对应的 `Key`
///    如果另一方在第二阶段之前停滞，该方可通过 `unlock` 恢复其对象以保持活性（liveness）
///
/// 2. 另一方注册一个对外可见的、共享的 `Escrow` 对象
///    这实际上会在特定版本上锁定他们的对象，等待第一方完成交换第二方也可以请求将对象退回以保持活性
///
/// 3. 第一方将其锁定的对象和密钥发送给共享的 `Escrow` 对象
///    只要满足所有条件，交换便会完成：
///
///    - 发起交换交易的发送者必须是该 `Escrow` 的接收者（recipient）
///
///    - 托管中所需对象的密钥（`exchange_key`）必须与交换中提供的 key 匹配
///
///    - 交换中提供的 key 必须能解开 `Locked<U>`
module escrow::shared;

use escrow::lock::{Locked, Key};
use sui::dynamic_object_field as dof;
use sui::event;

/// 存放在 DOF 中以标识被托管对象的字段名类型，便于发现托管对象
public struct EscrowedObjectKey has copy, drop, store {}

/// 被托管的对象
///
/// 托管对象作为一个动态对象字段（Dynamic Object Field）被添加，从而仍然可以被查找
public struct Escrow<phantom T: key + store> has key, store {
    id: UID,
    /// `escrowed` 的拥有者
    sender: address,
    /// 预期接收者
    recipient: address,
    /// 打開发送方期望从接收方获取的对象的 Key 的 ID
    exchange_key: ID,
}

// === 错误码 ===

/// 两个 escrow 的 `sender` 与 `recipient` 不匹配
const EMismatchedSenderRecipient: u64 = 0;

/// 两个 escrow 的 `exchange_for` 字段不匹配
const EMismatchedExchangeObject: u64 = 1;

// === 公共函数 ===
public fun create<T: key + store>(
    escrowed: T,
    exchange_key: ID,
    recipient: address,
    ctx: &mut TxContext,
) {
    let mut escrow = Escrow<T> {
        id: object::new(ctx),
        sender: ctx.sender(),
        recipient,
        exchange_key,
    };
    event::emit(EscrowCreated {
        escrow_id: object::id(&escrow),
        key_id: exchange_key,
        sender: escrow.sender,
        recipient,
        item_id: object::id(&escrowed),
    });

    // 将被托管对象作为 DOF 添加到 escrow 中
    dof::add(&mut escrow.id, EscrowedObjectKey {}, escrowed);

    transfer::public_share_object(escrow);
}

/// `recipient` 可以用 `obj` 与托管对象进行交换
public fun swap<T: key + store, U: key + store>(
    mut escrow: Escrow<T>,
    key: Key,
    locked: Locked<U>,
    ctx: &TxContext,
): T {
    // 从 DOF 中移除托管的对象
    let escrowed = dof::remove<EscrowedObjectKey, T>(&mut escrow.id, EscrowedObjectKey {});

    let Escrow {
        id,
        sender,
        recipient,
        exchange_key,
    } = escrow;

    // 只有托管的接收者可以完成交换
    assert!(recipient == ctx.sender(), EMismatchedSenderRecipient);
    // 只有当托管内期望的密钥与交换时提供的 key 相同时，交换才会进行
    assert!(exchange_key == object::id(&key), EMismatchedExchangeObject);

    // 执行实际交换：用提供的 key 解锁 locked 并把对象转给原始发送者
    transfer::public_transfer(locked.unlock(key), sender);

    event::emit(EscrowSwapped {
        escrow_id: id.to_inner(),
    });

    id.delete();

    escrowed
}

/// 创建者可以取消托管并取回被托管对象
public fun return_to_sender<T: key + store>(mut escrow: Escrow<T>, ctx: &TxContext): T {
    event::emit(EscrowCancelled {
        escrow_id: object::id(&escrow),
    });

    let escrowed = dof::remove<EscrowedObjectKey, T>(&mut escrow.id, EscrowedObjectKey {});

    let Escrow {
        id,
        sender,
        recipient: _,
        exchange_key: _,
    } = escrow;

    // 只有原始发送者可以取回被托管对象
    assert!(sender == ctx.sender(), EMismatchedSenderRecipient);
    id.delete();
    escrowed
}

// === 事件 ===
public struct EscrowCreated has copy, drop {
    /// 创建的 escrow 的 ID
    escrow_id: ID,
    /// 用于解锁所请求对象的 `Key` 的 ID
    key_id: ID,
    /// 交换中将接收 `T` 的发送者 ID
    sender: address,
    /// 被托管对象的（原始）接收者
    recipient: address,
    /// 被托管物品的 ID
    item_id: ID,
}

public struct EscrowSwapped has copy, drop {
    escrow_id: ID,
}

public struct EscrowCancelled has copy, drop {
    escrow_id: ID,
}

// === 测试 ===
#[test_only]
use sui::coin::{Self, Coin};
#[test_only]
use sui::sui::SUI;
#[test_only]
use sui::test_scenario::{Self as ts, Scenario};

#[test_only]
use escrow::lock;

#[test_only]
const ALICE: address = @0xA;
#[test_only]
const BOB: address = @0xB;
#[test_only]
const DIANE: address = @0xD;

#[test_only]
fun test_coin(ts: &mut Scenario): Coin<SUI> {
    coin::mint_for_testing<SUI>(42, ts.ctx())
}
#[test]
fun test_successful_swap() {
    let mut ts = ts::begin(@0x0);

    // Bob 锁定他们想要交易的对象
    let (i2, ik2) = {
        ts.next_tx(BOB);
        let c = test_coin(&mut ts);
        let cid = object::id(&c);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, BOB);
        transfer::public_transfer(k, BOB);
        (cid, kid)
    };

    // Alice 创建一个公开的 Escrow 来持有她愿意分享的对象，以及她想要从 Bob 那里得到的对象
    let i1 = {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        let cid = object::id(&c);
        create(c, ik2, BOB, ts.ctx());
        cid
    };

    // Bob 响应，通过提供他们的对象并从 Alice 那里换取对象
    {
        ts.next_tx(BOB);
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        let k2: Key = ts.take_from_sender();
        let l2: Locked<Coin<SUI>> = ts.take_from_sender();
        let c = escrow.swap(k2, l2, ts.ctx());

        transfer::public_transfer(c, BOB);
    };
    // 提交交换的效果
    ts.next_tx(@0x0);

    // Alice 从 Bob 那里得到对象
    {
        let c: Coin<SUI> = ts.take_from_address_by_id(ALICE, i2);
        ts::return_to_address(ALICE, c);
    };

    // Bob 从 Alice 那里得到对象
    {
        let c: Coin<SUI> = ts.take_from_address_by_id(BOB, i1);
        ts::return_to_address(BOB, c);
    };

    ts::end(ts);
}

#[test]
#[expected_failure(abort_code = EMismatchedSenderRecipient)]
fun test_mismatch_sender() {
    let mut ts = ts::begin(@0x0);

    let ik2 = {
        ts.next_tx(DIANE);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, DIANE);
        transfer::public_transfer(k, DIANE);
        kid
    };

    // Alice 想与 Bob 交易
    {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        create(c, ik2, BOB, ts.ctx());
    };

    // 但 Diane 是尝试进行交换的一方
    {
        ts.next_tx(DIANE);
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        let k2: Key = ts.take_from_sender();
        let l2: Locked<Coin<SUI>> = ts.take_from_sender();
        let c = escrow.swap(k2, l2, ts.ctx());

        transfer::public_transfer(c, DIANE);
    };

    abort 1337
}

#[test]
#[expected_failure(abort_code = EMismatchedExchangeObject)]
fun test_mismatch_object() {
    let mut ts = ts::begin(@0x0);

    {
        ts.next_tx(BOB);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        transfer::public_transfer(l, BOB);
        transfer::public_transfer(k, BOB);
    };

    // Alice 想与 Bob 交易，但 Alice 要求的对象（通过其 `exchange_key`）并非 Bob 已放入交换的对象
    {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        let cid = object::id(&c);
        create(c, cid, BOB, ts.ctx());
    };

    // 当 Bob 尝试完成交换时，将会失败，因为他们无法满足 Alice 的要求
    {
        ts.next_tx(BOB);
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        let k2: Key = ts.take_from_sender();
        let l2: Locked<Coin<SUI>> = ts.take_from_sender();
        let c = escrow.swap(k2, l2, ts.ctx());

        transfer::public_transfer(c, BOB);
    };

    abort 1337
}

#[test]
#[expected_failure(abort_code = EMismatchedExchangeObject)]
fun test_object_tamper() {
    let mut ts = ts::begin(@0x0);

    // Bob 锁定他们的对象
    let ik2 = {
        ts.next_tx(BOB);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, BOB);
        transfer::public_transfer(k, BOB);
        kid
    };

    // Alice 设置托管
    {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        create(c, ik2, BOB, ts.ctx());
    };

    // Bob 改变主意，他解锁对象并对其进行篡改，但 Bob 无法隐藏此类篡改
    {
        ts.next_tx(BOB);
        let k: Key = ts.take_from_sender();
        let l: Locked<Coin<SUI>> = ts.take_from_sender();
        let mut c = lock::unlock(l, k);

        let _dust = c.split(1, ts.ctx());
        let (l, k) = lock::lock(c, ts.ctx());
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        let c = escrow.swap(k, l, ts.ctx());

        transfer::public_transfer(c, BOB);
    };

    abort 1337
}

#[test]
fun test_return_to_sender() {
    let mut ts = ts::begin(@0x0);

    // Alice 将她想交易的对象放入托管
    let cid = {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        let cid = object::id(&c);
        let i = object::id_from_address(@0x0);
        create(c, i, BOB, ts.ctx());
        cid
    };

    // ...但她改变主意并取回它
    {
        ts.next_tx(ALICE);
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        let c = escrow.return_to_sender(ts.ctx());

        transfer::public_transfer(c, ALICE);
    };

    ts.next_tx(@0x0);

    // Alice 然后可以访问它
    {
        let c: Coin<SUI> = ts.take_from_address_by_id(ALICE, cid);
        ts::return_to_address(ALICE, c)
    };

    ts::end(ts);
}

#[test]
#[expected_failure]
fun test_return_to_sender_failed_swap() {
    let mut ts = ts::begin(@0x0);

    // Bob 锁定他们的对象
    let ik2 = {
        ts.next_tx(BOB);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, BOB);
        transfer::public_transfer(k, BOB);
        kid
    };

    // Alice 创建一个公开的 Escrow 来持有她愿意分享的对象，以及她想要从 Bob 那里得到的对象
    {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        create(c, ik2, BOB, ts.ctx());
    };

    // ...但然后她改变主意
    {
        ts.next_tx(ALICE);
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        let c = escrow.return_to_sender(ts.ctx());
        transfer::public_transfer(c, ALICE);
    };

    // Bob 现在尝试完成交换将失败
    {
        ts.next_tx(BOB);
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        let k2: Key = ts.take_from_sender();
        let l2: Locked<Coin<SUI>> = ts.take_from_sender();
        let c = escrow.swap(k2, l2, ts.ctx());

        transfer::public_transfer(c, BOB);
    };

    abort 1337
}
