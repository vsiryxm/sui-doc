/// https://github.com/MystenLabs/sui/blob/main/examples/trading/contracts/escrow/sources/owned.move
/// 
/// 使用单个所有者交易进行对象原子交换的托管（escrow）示例，
/// 信任第三方以保证活性（liveness），但不信任第三方保证安全性（safety）
///
/// 通过 Escrow 进行的交换分为三阶段：
///
/// 1. 双方各自将自己的对象 `lock`，得到 `Locked` 对象和一个 `Key`
///    每方都可以 `unlock` 自己的对象，以便在另一方在第二阶段停滞时保留活性
///
/// 2. 双方将 `Escrow` 对象注册给托管方（custodian），这要求将被锁定的对象及其密钥一并提交
///    该密钥会被消耗用于解开锁，但密钥的 ID 会被记录下来，以便托管方能确认被交换的对象是否正确
///    托管方被信任以保证活性
///
/// 3. 只要满足所有条件，托管方就会交换被锁的对象：
///
///    - 两个 Escrow 的发送者（sender）和接收者（recipient）应互为对方的接收者和发送者
///      如果不满足，说明托管方错误地将两个不相关的交换配对在一起
///
///    - 所需对象的密钥（`exchange_key`）应与另一个对象被锁时使用的密钥（`escrowed_key`）相匹配，反之亦然
///
///      若不匹配，则说明被交换的对象不对，可能是因为托管方配对了错误的 escrow 对象，
///      或者某一方在锁定后篡改了他们的对象
///
///      所讨论的密钥是 `Key` 对象的 ID，该 `Key` 用于解开在被发送给托管方前各自对象所处的 `Locked` 对象
module escrow::owned;

use escrow::lock::{Locked, Key};

/// 托管中持有的对象
public struct Escrow<T: key + store> has key {
    id: UID,
    /// `escrowed` 的拥有者
    sender: address,
    /// 预期接收者
    recipient: address,
    /// 用于打开接收者对象锁的 Key 的 ID（发送方期望从接收方获得的对象）
    exchange_key: ID,
    /// 在对象被托管前，用来锁定该被托管对象的 Key 的 ID
    escrowed_key: ID,
    /// 被托管的对象
    escrowed: T,
}

// === 错误码 ===

/// 两个 escrowed 对象的 `sender` 与 `recipient` 不匹配
const EMismatchedSenderRecipient: u64 = 0;

/// 两个 escrowed 对象的 `exchange_key` 字段不匹配
const EMismatchedExchangeObject: u64 = 1;

// === 公共函数 ===

/// `ctx.sender()` 请求与 `recipient` 进行一次交换：
/// 将一个已锁定的对象 `locked` 交换为由 `exchange_key` 指定的对象
/// 该交换由第三方 `custodian`（托管方）执行，托管方被信任以保持活性，但不被信任保证安全性
///（托管方只能负责推进交换的流程）
///
/// `locked` 在发送给托管方前，会用对应的 `key` 解锁，但在交换成功执行或托管方归还对象前，
/// 底层对象仍不可访问
///
/// `exchange_key` 是能解开发送方期望接收对象的 `Key` 的 ID以密钥为交换条件可以保证：
/// 如果接收方在发送方的对象被托管后尝试篡改目标对象，则交换不会成功——因为接收方
/// 必须消耗密钥来篡改对象，若其重新上锁则会使用不同的、不可兼容的密钥，导致匹配失败
public fun create<T: key + store>(
    key: Key,
    locked: Locked<T>,
    exchange_key: ID,
    recipient: address,
    custodian: address,
    ctx: &mut TxContext,
) {
    let escrow = Escrow {
        id: object::new(ctx),
        sender: ctx.sender(),
        recipient,
        exchange_key,
        escrowed_key: object::id(&key),
        escrowed: locked.unlock(key),
    };

    transfer::transfer(escrow, custodian);
}

/// 由托管方（受信任的第三方）在两个参与方之间执行交换的函数
/// 如果它们的发送者与接收者不匹配，或它们各自期望的对象不匹配，则失败
public fun swap<T: key + store, U: key + store>(obj1: Escrow<T>, obj2: Escrow<U>) {
    let Escrow {
        id: id1,
        sender: sender1,
        recipient: recipient1,
        exchange_key: exchange_key1,
        escrowed_key: escrowed_key1,
        escrowed: escrowed1,
    } = obj1;

    let Escrow {
        id: id2,
        sender: sender2,
        recipient: recipient2,
        exchange_key: exchange_key2,
        escrowed_key: escrowed_key2,
        escrowed: escrowed2,
    } = obj2;
    id1.delete();
    id2.delete();

    // 确认发送者和接收者相互匹配
    assert!(sender1 == recipient2, EMismatchedSenderRecipient);
    assert!(sender2 == recipient1, EMismatchedSenderRecipient);

    // 确认对象彼此匹配且未被修改（它们保持被锁定状态）
    assert!(escrowed_key1 == exchange_key2, EMismatchedExchangeObject);
    assert!(escrowed_key2 == exchange_key1, EMismatchedExchangeObject);

    // 执行实际交换
    transfer::public_transfer(escrowed1, recipient1);
    transfer::public_transfer(escrowed2, recipient2);
}

/// 托管方可以随时将被托管对象退回其原始拥有者
public fun return_to_sender<T: key + store>(obj: Escrow<T>) {
    let Escrow {
        id,
        sender,
        recipient: _,
        exchange_key: _,
        escrowed_key: _,
        escrowed,
    } = obj;
    id.delete();
    transfer::public_transfer(escrowed, sender);
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
const CUSTODIAN: address = @0xC;
#[test_only]
const DIANE: address = @0xD;

#[test_only]
fun test_coin(ts: &mut Scenario): Coin<SUI> {
    coin::mint_for_testing<SUI>(42, ts::ctx(ts))
}

#[test]
fun test_successful_swap() {
    let mut ts = ts::begin(@0x0);

    // Alice 锁定她想要交易的对象
    let (i1, ik1) = {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        let cid = object::id(&c);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, ALICE);
        transfer::public_transfer(k, ALICE);
        (cid, kid)
    };

    // Bob 也将他的对象锁定
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

    // Alice 将她的对象交给托管方作为托管
    {
        ts.next_tx(ALICE);
        let k1: Key = ts.take_from_sender();
        let l1: Locked<Coin<SUI>> = ts.take_from_sender();
        create(k1, l1, ik2, BOB, CUSTODIAN, ts.ctx());
    };

    // Bob 也做同样的操作
    {
        ts.next_tx(BOB);
        let k2: Key = ts.take_from_sender();
        let l2: Locked<Coin<SUI>> = ts.take_from_sender();
        create(k2, l2, ik1, ALICE, CUSTODIAN, ts.ctx());
    };

    // 托管方执行交换
    {
        ts.next_tx(CUSTODIAN);
        swap<Coin<SUI>, Coin<SUI>>(
            ts.take_from_sender(),
            ts.take_from_sender(),
        );
    };

    // 提交交换的效果
    ts.next_tx(@0x0);

    // Alice 从 Bob 那里取回对象
    {
        let c: Coin<SUI> = ts.take_from_address_by_id(ALICE, i2);
        ts::return_to_address(ALICE, c);
    };

    // Bob 从 Alice 那里取回对象
    {
        let c: Coin<SUI> = ts.take_from_address_by_id(BOB, i1);
        ts::return_to_address(BOB, c);
    };

    ts.end();
}

#[test]
#[expected_failure(abort_code = EMismatchedSenderRecipient)]
fun test_mismatch_sender() {
    let mut ts = ts::begin(@0x0);

    let ik1 = {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, ALICE);
        transfer::public_transfer(k, ALICE);
        kid
    };

    let ik2 = {
        ts.next_tx(BOB);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, BOB);
        transfer::public_transfer(k, BOB);
        kid
    };

    // Alice 希望与 Bob 交易
    {
        ts.next_tx(ALICE);
        let k1: Key = ts.take_from_sender();
        let l1: Locked<Coin<SUI>> = ts.take_from_sender();
        create(k1, l1, ik2, BOB, CUSTODIAN, ts.ctx());
    };

    // 但 Bob 想与 Diane 交易
    {
        ts.next_tx(BOB);
        let k2: Key = ts.take_from_sender();
        let l2: Locked<Coin<SUI>> = ts.take_from_sender();
        create(k2, l2, ik1, DIANE, CUSTODIAN, ts.ctx());
    };

    // 当托管方尝试匹配交换时，将会失败
    {
        ts.next_tx(CUSTODIAN);
        swap<Coin<SUI>, Coin<SUI>>(
            ts.take_from_sender(),
            ts.take_from_sender(),
        );
    };

    abort 1337
}

#[test]
#[expected_failure(abort_code = EMismatchedExchangeObject)]
fun test_mismatch_object() {
    let mut ts = ts::begin(@0x0);

    let ik1 = {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, ALICE);
        transfer::public_transfer(k, ALICE);
        kid
    };

    {
        ts.next_tx(BOB);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        transfer::public_transfer(l, BOB);
        transfer::public_transfer(k, BOB);
    };

    // Alice 想与 Bob 交易，但 Alice 指定了一个 Bob 并未用于此次交换的对象（通过其 `exchange_key`）
    {
        ts.next_tx(ALICE);
        let k1: Key = ts.take_from_sender();
        let l1: Locked<Coin<SUI>> = ts.take_from_sender();
        create(k1, l1, ik1, BOB, CUSTODIAN, ts.ctx());
    };

    {
        ts.next_tx(BOB);
        let k2: Key = ts.take_from_sender();
        let l2: Locked<Coin<SUI>> = ts.take_from_sender();
        create(k2, l2, ik1, ALICE, CUSTODIAN, ts.ctx());
    };

    // 当托管方尝试匹配交换时，将会失败
    {
        ts.next_tx(CUSTODIAN);
        swap<Coin<SUI>, Coin<SUI>>(
            ts.take_from_sender(),
            ts.take_from_sender(),
        );
    };

    abort 1337
}

#[test]
#[expected_failure(abort_code = EMismatchedExchangeObject)]
fun test_object_tamper() {
    let mut ts = ts::begin(@0x0);

    // Alice 锁定她想要交易的对象
    let ik1 = {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, ALICE);
        transfer::public_transfer(k, ALICE);
        kid
    };

    // Bob 也将他的对象锁定
    let ik2 = {
        ts.next_tx(BOB);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, BOB);
        transfer::public_transfer(k, BOB);
        kid
    };

    // Alice 将她的对象交给托管方作为托管
    {
        ts.next_tx(ALICE);
        let k1: Key = ts.take_from_sender();
        let l1: Locked<Coin<SUI>> = ts.take_from_sender();
        create(k1, l1, ik2, BOB, CUSTODIAN, ts.ctx());
    };

    // Bob 临时改变主意，他解锁对象并对其进行篡改
    {
        ts.next_tx(BOB);
        let k: Key = ts.take_from_sender();
        let l: Locked<Coin<SUI>> = ts.take_from_sender();
        let mut c = lock::unlock(l, k);

        let _dust = coin::split(&mut c, 1, ts.ctx());
        let (l, k) = lock::lock(c, ts.ctx());
        create(k, l, ik1, ALICE, CUSTODIAN, ts.ctx());
    };

    // 当托管方执行交换时，它会检测到 Bob 的恶意行为
    {
        ts.next_tx(CUSTODIAN);
        swap<Coin<SUI>, Coin<SUI>>(
            ts.take_from_sender(),
            ts.take_from_sender(),
        );
    };

    abort 1337
}

#[test]
fun test_return_to_sender() {
    let mut ts = ts::begin(@0x0);

    // Alice 锁定她想要交易的对象
    let cid = {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        let cid = object::id(&c);
        let (l, k) = lock::lock(c, ts.ctx());
        let i = object::id_from_address(@0x0);
        create(k, l, i, BOB, CUSTODIAN, ts.ctx());
        cid
    };

    // 托管方将其退回
    {
        ts.next_tx(CUSTODIAN);
        return_to_sender<Coin<SUI>>(ts.take_from_sender());
    };

    ts.next_tx(@0x0);

    // Alice 然后可以访问它
    {
        let c: Coin<SUI> = ts.take_from_address_by_id(ALICE, cid);
        ts::return_to_address(ALICE, c)
    };

    ts.end();
}
