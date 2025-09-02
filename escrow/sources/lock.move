// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// `lock` 模块提供一个 API，用于包装任何拥有
/// `store` 能力的对象，并通过一次性使用的 `Key` 进行保护。
///
/// 这用于在托管（escrow）期间，对某个特定对象在某个
/// 固定状态下的交换作出承诺。
module escrow::lock;

use sui::dynamic_object_field as dof;
use sui::event;

/// 持有被锁定对象的动态对象字段（DOF）的 `name`。
/// 便于更好地检索被锁定的对象。
public struct LockedObjectKey has copy, drop, store {}

/// 一个包装器：通过要求提供 `Key` 来保护对 `obj` 的访问。
///
/// 用于确保某个对象如果可能参与一笔交换时，不会被修改。
///
/// 对象被作为动态对象字段添加，这样仍然可以被查找。
public struct Locked<phantom T: key + store> has key, store {
    id: UID,
    key: ID,
}

/// 打开被锁定对象的钥匙（消耗该 `Key`）
public struct Key has key, store { id: UID }

// === 错误码 ===

/// 提供的 key 与该锁不匹配。
const ELockKeyMismatch: u64 = 0;

// === 公共函数 ===

/// 锁定 `obj` 并返回一个可用于解锁它的 key。
public fun lock<T: key + store>(obj: T, ctx: &mut TxContext): (Locked<T>, Key) {
    let key = Key { id: object::new(ctx) };
    let mut lock = Locked {
        id: object::new(ctx),
        key: object::id(&key),
    };

    event::emit(LockCreated {
        lock_id: object::id(&lock),
        key_id: object::id(&key),
        creator: ctx.sender(),
        item_id: object::id(&obj),
    });

    // 将 `object` 作为一个动态对象字段添加到 `lock` 对象中
    dof::add(&mut lock.id, LockedObjectKey {}, obj);

    (lock, key)
}

/// 使用 `key` 解锁 `locked` 中的对象（消耗该 key）。如果传入的
/// `key` 不正确则失败。
public fun unlock<T: key + store>(mut locked: Locked<T>, key: Key): T {
    assert!(locked.key == object::id(&key), ELockKeyMismatch);
    let Key { id } = key;
    id.delete();

    let obj = dof::remove<LockedObjectKey, T>(&mut locked.id, LockedObjectKey {});

    event::emit(LockDestroyed { lock_id: object::id(&locked) });

    let Locked { id, key: _ } = locked;
    id.delete();
    obj
}

// === 事件 ===
public struct LockCreated has copy, drop {
    /// `Locked` 对象的 ID。
    lock_id: ID,
    /// 可用于解锁 `Locked` 中被锁对象的 key 的 ID。
    key_id: ID,
    /// 锁定该对象的创建者地址。
    creator: address,
    /// 被锁定项目的 ID。
    item_id: ID,
}

public struct LockDestroyed has copy, drop {
    /// `Locked` 对象的 ID。
    lock_id: ID,
}

// === 测试 ===
#[test_only]
use sui::coin::{Self, Coin};
#[test_only]
use sui::sui::SUI;
#[test_only]
use sui::test_scenario::{Self as ts, Scenario};

#[test_only]
fun test_coin(ts: &mut Scenario): Coin<SUI> {
    coin::mint_for_testing<SUI>(42, ts.ctx())
}

#[test]
fun test_lock_unlock() {
    let mut ts = ts::begin(@0xA);
    let coin = test_coin(&mut ts);

    let (lock, key) = lock(coin, ts.ctx());
    let coin = lock.unlock(key);

    coin.burn_for_testing();
    ts.end();
}

#[test]
#[expected_failure(abort_code = ELockKeyMismatch)]
fun test_lock_key_mismatch() {
    let mut ts = ts::begin(@0xA);
    let coin = test_coin(&mut ts);
    let another_coin = test_coin(&mut ts);
    let (l, _k) = lock(coin, ts.ctx());
    let (_l, k) = lock(another_coin, ts.ctx());

    let _key = l.unlock(k);
    abort 1337
}
