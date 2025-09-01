module my_first_package::example;

// Part 1: 以下包不用显式导入，因为Move 2024版本编译器会默认导入
// use sui::object::{Self, UID};
// use sui::transfer;
// use sui::tx_context::{Self, TxContext};

// 调试时引入debug包
// use std::debug;

// Part 2: 剑结构体定义
// Move 2024 要求所有结构体都必须使用public关键字声明
// 如果结构体定义成has key，则表明由这个结构体产生的对象可以作为全局对象/资源，存储于链上，可以在地址之间转移
// 如果结构体定义成has store，则表明这个结构体产生的对象可以持久存储或被包含在其它结构体字段中，但并不意味着可被复制或丢弃（这由 copy/drop 能力决定）
public struct Sword has key, store {
    id: UID,
    magic: u64,
    strength: u64,
}

public struct Forge has key {
    id: UID,
    swords_created: u64,
}

// Part 3: 模块初始化函数，类似solidity中的constructor
// 在模块 publish（部署）事务中会被调用一次，用于初始对象创建/状态初始化
fun init(ctx: &mut TxContext) {
    // 创建一个 Forge 对象
    let admin = Forge {
        id: object::new(ctx),
        swords_created: 0,
    };

    // 将 Forge 对象转移给合约部署者
    transfer::transfer(admin, ctx.sender());
}

// Part 4: 读取Sword对象的属性
// 在 Move 中，结构体上的访问器通常作为普通函数调用，使用 magic(&sword) 而不是 sword.magic()
// 也可以直接读字段 sword.magic（当字段可见时）
public fun magic(self: &Sword): u64 {
    self.magic
}

public fun strength(self: &Sword): u64 {
    self.strength 
}

public fun swords_created(self: &Forge): u64 {
    self.swords_created
}

// Part 5: 公共/入口函数
public fun sword_create(magic: u64, strength: u64, ctx: &mut TxContext): Sword {
    Sword {
        id: object::new(ctx),
        magic: magic,
        strength: strength,
    }
}

public fun new_sword(forge: &mut Forge, magic: u64, strength: u64, ctx: &mut TxContext): Sword {
    // 调试合约时，开启以下debug语句
    // debug::print(forge);
    forge.swords_created = forge.swords_created + 1;
    // debug::print(forge);
    // debug::print_stack_trace();
    Sword {
        id: object::new(ctx),
        magic: magic,
        strength: strength,
    }
}

// Part 6: 单元测试
#[test]
fun test_sword_create() {
    // 创建一个虚拟的 TxContext 进行测试
    let mut ctx = tx_context::dummy();

    // 创建一把剑
    let sword = Sword {
        id: object::new(&mut ctx),
        magic: 42,
        strength: 7,
    };

    // 检查访问器函数是否返回正确的值
    assert!(sword.magic() == 42 && sword.strength() == 7, 1);

    // 在Move中，创建对象后，要么丢弃要么转移，不能隐匿
    // sword对象被创建后，由于Sword没有drop属性，所以不能丢弃，只能转移
    // Move的资源语义要求资源不能被隐式丢弃；如果类型不具有 drop 能力，不能调用允许丢弃的操作，必须将其移动到其它变量、返回、存入结构体或通过转移函数交出所有权。
    // 创建一个虚拟地址并转移剑
    let dummy_address = @0xCAFE;
    transfer::public_transfer(sword, dummy_address);

}

#[test]
fun test_sword_transactions() {
    use sui::test_scenario;
    /*
       sui::test_scenario的作用：
       想在单元测试里模拟“多笔链上交易间对象如何移动”，就用 test_scenario —— 它充当一个本地的“小型 Sui 环境”，允许你在第 1 笔交易创建对象、第 2 笔交易取出并转移、第 3 笔交易验证结果；take_from_sender 是把地址下的对象交给当前事务操作的工具，解决了“纯 Move 没有跨事务存储”的问题。
       sui::test_scenario 是用来在测试里按顺序模拟多笔有联系的交易并管理每个地址的对象池，这样第一笔创建的对象能在后续的交易里被取出、转移或验证（通过 take_from_sender/return_to_sender 等 API），但记住它是按交易边界模拟可见性，不是把多笔交易合并成一笔。
    */
    
    // 创建代表用户的测试地址
    let initial_owner = @0xCAFE;
    let final_owner = @0xFACE;

    // 第一笔交易，为initial_owner铸造一把剑
    let mut scenario = test_scenario::begin(initial_owner);
    {
        // 创建剑并将其转移给initial_owner
        let sword = sword_create(42, 7, scenario.ctx());
        transfer::public_transfer(sword, initial_owner);
    };

    // 第二笔交易，由初始剑的initial_owner执行
    scenario.next_tx(initial_owner);
    {
        // 获取initial_owner拥有的剑
        let sword = scenario.take_from_sender<Sword>();
        // 将剑转移给final_owner
        transfer::public_transfer(sword, final_owner);
    };

    // 第三笔交易，由最终剑的拥有者执行
    scenario.next_tx(final_owner);
    {
        // 获取final_owner拥有的剑
        let sword = scenario.take_from_sender<Sword>();
        // 验证剑的属性是否符合预期
        assert!(sword.magic() == 42 && sword.strength() == 7, 1);
        // 将剑返回给对象池（不能简单地“丢弃”）
        scenario.return_to_sender(sword)
    };
    scenario.end();
}

#[test]
fun test_module_init() {
    use sui::test_scenario;

    // 创建代表用户的测试地址
    let admin = @0xAD;
    let initial_owner = @0xCAFE;

    // 第一笔交易模拟模块初始化
    let mut scenario = test_scenario::begin(admin);
    {
        // 显式调用初始化函数
        init(scenario.ctx());
    };

    // 第二笔交易由admin执行，检查Forge对象是否已创建且初始值为0
    scenario.next_tx(admin);
    {
        // 提取Forge对象
        let forge = scenario.take_from_sender<Forge>();
        // 验证已创建的剑的数量
        assert!(forge.swords_created() == 0, 1);
        // 将Forge对象返回给对象池
        scenario.return_to_sender(forge);
    };

    // 第三笔交易由admin执行，创建剑并将其转移给initial_owner
    scenario.next_tx(admin);
    {
        let mut forge = scenario.take_from_sender<Forge>();
        // 创建剑并将其转移给initial_owner
        let sword = forge.new_sword(42, 7, scenario.ctx());
        transfer::public_transfer(sword, initial_owner);
        scenario.return_to_sender(forge);
    };
    scenario.end();
}