
# 构建你的第一个Sui APP

## 一、创建合约项目

打开终端，使用 `sui move new` 命令创建一个名为 `my_first_package` 的空 Move 包：
```
$ sui move new my_first_package
```
该命令将为你创建一个合约项目 `my_first_package`，并对项目进行初始化，包括 `sources/my_first_package.move` 合约、`Move.toml` 配置文件、测试目录等。

先来看看配置文件：

```toml
[package]
name = "my_first_package"
edition = "2024.beta" # edition = "legacy" to use legacy (pre-2024) Move
license = "MIT"           # e.g., "MIT", "GPL", "Apache 2.0"
authors = ["Simon (blockman1024@gmail.com)"]      # e.g., ["Joe Smith (joesmith@noemail.com)", "John Snow (johnsnow@noemail.com)"]

[dependencies]

# For remote import, use the `{ git = "...", subdir = "...", rev = "..." }`.
# Revision can be a branch, a tag, and a commit hash.
# MyRemotePackage = { git = "https://some.remote/host.git", subdir = "remote/path", rev = "main" }

# For local dependencies use `local = path`. Path is relative to the package root
# Local = { local = "../path/to" }

# To resolve a version conflict and force a specific version for dependency
# override use `override = true`
# Override = { local = "../conflicting/version", override = true }

[addresses]
my_first_package = "0x0"

# Named addresses will be accessible in Move as `@name`. They're also exported:
# for example, `std = "0x1"` is exported by the Standard Library.
# alice = "0xA11CE"

[dev-dependencies]
# The dev-dependencies section allows overriding dependencies for `--test` and
# `--dev` modes. You can introduce test-only dependencies here.
# Local = { local = "../path/to/dev-build" }

[dev-addresses]
# The dev-addresses section allows overwriting named addresses for the `--test`
# and `--dev` modes.
# alice = "0xB0B"

```
- [package]：包含包的元数据，默认情况下，`sui move new`命令仅填充name元数据的值。在本例中，命令中的参数值 my_first_package 会被当成包的名称，你还可以去除行前 # 号来开启其它字段的配置，如license。
- [dependencies]：列出你的包运行时所依赖的其他软件包。默认情况下，`sui move new`命令会将Sui GitHub 上的软件包（Testnet 版本）列为唯一依赖项。
- [addresses]：声明你的软件包使用的命名地址。默认情况下，此部分包含你使用命令创建的软件包sui move new以及一个地址 0x0。此值可以保留原样，表示软件包地址在发布和升级时会自动管理。
- [dev-dependencies]：仅包含描述该部分的注释。
- [dev-addresses]：仅包含描述该部分的注释。

## 二、编写合约

我们将 `sources/my_first_package.move` 重命名为 `example.move`，并在IDE中打开它：

```move
module my_first_package::example; // 此处也要记得重命名

// Part 1: 以下这些包，编译器会默认提供，不需要显式导入
// use sui::object::{Self, UID};
// use sui::transfer;
// use sui::tx_context::{Self, TxContext};

// Part 2: 剑结构体定义
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
// Part 6: 单元测试
```

前面代码中的注释指出了典型 Move 源文件的不同部分：

**Part 1：Imports（导入）**

* 现代编程中，代码复用是必需的。Move 支持这一概念，通过 **use 别名** 可以让模块引用其他模块中声明的类型和函数。
* 在这个例子里，模块导入了 `object`、`transfer` 和 `tx_context` 模块，但实际上无需显式导入，因为编译器默认提供这些 use 语句。
* 这些模块之所以可用，是因为 `Move.toml` 文件定义了 Sui 依赖（以及 sui 命名地址），这些模块就在其中定义。

**Part 2：Struct declarations（结构体声明）**

* 结构体定义了模块可以创建或销毁的类型。
* 结构体定义中可以使用 `has` 关键字指定能力（abilities）。
* 本例中的结构体具有 **key** 能力，表示它们是可在地址间转移的 Sui 对象。
* **store** 能力允许结构体出现在其他结构体字段中，并可自由转移。

**Part 3：Module initializer（模块初始化函数）**

* 一个特殊函数，在模块发布时 **只会被调用一次**。

**Part 4：Accessor functions（访问器函数）**

* 这些函数允许其他模块读取模块结构体的字段。

当你保存文件后，就完成了一个 **完整的 Move 包**。


## 三、编译合约

```bash
$ sui move build
```
编译成功后将返回以下类似内容：
```
INCLUDING DEPENDENCY Bridge
INCLUDING DEPENDENCY SuiSystem
INCLUDING DEPENDENCY Sui
INCLUDING DEPENDENCY MoveStdlib
BUILDING my_first_package
```

现在你已经设计了资产及其访问器函数，是时候开始单元测试了。

## 四、测试合约

### 4.1 单元测试

```bash
$ sui move test
```

如果你对在“编写包（Write a Package）”中创建的包执行该命令，你会看到如下输出：

毫不意外，由于还没有编写任何测试，测试结果显示 **OK** 状态，没有失败的测试用例。

```
INCLUDING DEPENDENCY Bridge
INCLUDING DEPENDENCY SuiSystem
INCLUDING DEPENDENCY Sui
INCLUDING DEPENDENCY MoveStdlib
BUILDING my_first_package
Running Move unit tests
Test result: OK. Total tests: 0; passed: 0; failed: 0
```

要真正测试你的代码，需要 **添加测试函数**。

首先，在 `example.move` 文件的模块定义内部，添加一个 **基础测试函数**：

```move
#[test]
fun test_sword_create() {
    // Create a dummy TxContext for testing
    let mut ctx = tx_context::dummy();

    // Create a sword
    let sword = Sword {
        id: object::new(&mut ctx),
        magic: 42,
        strength: 7,
    };

    // Check if accessor functions return correct values
    assert!(sword.magic() == 42 && sword.strength() == 7, 1);

}
```

如代码所示，单元测试函数 `test_sword_create()` 的流程如下：

1. **创建 TxContext 实例**

   * 生成一个伪（dummy）`TxContext` 实例，并赋值给 `ctx`。

2. **创建剑对象**

   * 使用 `ctx` 生成唯一标识符
   * 将 `magic` 参数设为 `42`，`strength` 设为 `7`

3. **验证访问器函数**

   * 调用 `magic` 和 `strength` 的访问器函数，确认返回值正确

需要注意的是：

* 测试函数将伪上下文 `ctx` 作为可变引用 (`&mut`) 传给 `object::new` 函数
* 但将 `sword` 对象作为只读引用 (`&sword`) 传给访问器函数

---

现在你已经有了一个测试函数，可以 **再次运行测试命令** 来执行验证。


```bash
$ sui move test
```
然而，在运行测试命令后，你并不是看到测试结果，而是出现了 **编译错误**：
```
BUILDING my_first_package
error[E06001]: unused value without 'drop'
   ┌─ ./sources/example.move:90:61
   │  
15 │   public struct Sword has key, store {
   │                 ----- To satisfy the constraint, the 'drop' ability would need to be added here
   ·  
83 │       let sword = Sword {
   │           ----- The local variable 'sword' still contains a value. The value does not have the 'drop' ability and must be consumed before the function returns
   │ ╭─────────────────'
84 │ │         id: object::new(&mut ctx),
85 │ │         magic: 42,
86 │ │         strength: 7,
87 │ │     };
   │ ╰─────' The type 'my_first_package::example::Sword' does not have the ability 'drop'
   · │
90 │       assert!(sword.magic() == 42 && sword.strength() == 7, 1);
   │                                                               ^ Invalid return
```

错误信息已经包含了调试代码所需的全部信息。这里的故障代码实际上是 **Move 语言安全特性的体现**。

* `Sword` 结构体表示一种游戏资产，数字化模拟现实中的物品。
* 显然，一把真实的剑不能凭空消失（虽然可以显式销毁），但数字物品没有这种限制。
* 在测试函数中正发生了类似情况——你创建了一个 `Sword` 实例，但在函数调用结束时它直接消失了。如果现实中你看到这样的现象，也会惊讶不已。

解决方案：

1. **错误提示建议**

   * 可以给 `Sword` 结构体添加 `drop` 能力，使其实例可以被销毁。
   * 但对有价值的资产来说，让它可以随意消失不是理想属性，因此需要其他方案。

2. **推荐方案**

   * **转移（transfer）剑的所有权**，而不是让它消失。

为让测试正常工作，需要使用 **transfer 模块**（默认已导入）。
在测试函数末尾（`assert!` 调用之后）添加如下代码，将剑的所有权转移到一个新创建的伪地址：

```move
let dummy_address = @0xCAFE;
transfer::public_transfer(sword, dummy_address);
```
再次运行测试命令后，输出显示 **已有一个测试成功通过** ✅。
```
INCLUDING DEPENDENCY Bridge
INCLUDING DEPENDENCY SuiSystem
INCLUDING DEPENDENCY Sui
INCLUDING DEPENDENCY MoveStdlib
BUILDING my_first_package
Running Move unit tests
[ PASS    ] my_first_package::example::test_sword_create
Test result: OK. Total tests: 1; passed: 1; failed: 0
```

> 你可以使用 **过滤字符串（filter string）** 来只运行匹配的单元测试子集。
>  * 提供过滤字符串后，`sui move test` 会根据 **完全限定名** (`<address>::<module_name>::<fn_name>`) 来匹配测试函数。
>  * 只有匹配的测试会被执行，其余测试会被忽略。

例如：
```bash
$ sui move test sword
```
上一个命令运行所有名称包含 sword 的测试。
你可以通过以下方式发现更多测试选项：
```bash
$ sui move test -h
```

### 4.2 Sui特定测试

之前的测试示例虽然使用了 Move，但除了用到一些 Sui 的包（如 `sui::tx_context` 和 `sui::transfer`）外，并没有真正针对 Sui 的特性。这样的测试方式对于在 Sui 上编写 Move 代码已经很有帮助，但如果你想验证更多 **Sui 特有的功能**，还需要进一步扩展。特别是，在 Sui 中一次 Move 调用会被封装在一笔 **Sui 交易** 中，你可能希望在一个测试中模拟不同交易之间的交互（例如：一笔交易创建一个对象，另一笔交易再将其转移）。

Sui 提供了一个 `test_scenario` 模块，用于支持这类 **Sui 专属测试**，提供纯 Move 及其测试框架中不具备的功能。

`test_scenario` 模块提供了一种场景（scenario），用于模拟一系列 Sui 交易，每笔交易都可能由不同的用户执行。测试通常会先调用 `test_scenario::begin` 函数开启第一笔交易。该函数接收一个用户地址作为参数，返回一个表示场景的 `Scenario` 结构体实例。

`Scenario` 结构体实例包含了一个按地址划分的对象池，用于模拟 Sui 的对象存储，并提供了一些辅助函数来操作对象池中的对象。第一笔交易完成后，后续的测试交易则通过 `test_scenario::next_tx` 函数开启。该函数需要传入当前的 `Scenario` 实例以及要执行交易的用户地址。

接下来，请更新你的 `example.move` 文件，添加一个可以在 Sui 上调用的函数，用于实现 **剑（sword）的创建**。完成后，你就可以基于此，新增一个 **多交易测试**，利用 `test_scenario` 模块来验证这些新能力。把这个函数写在访问器函数（注释中的 Part 5 部分）之后。

```move
public fun sword_create(magic: u64, strength: u64, ctx: &mut TxContext): Sword {
    Sword {
        id: object::new(ctx),
        magic: magic,
        strength: strength,
    }
}
```

新增的函数代码会用到 结构体创建 和 Sui 内部模块（如 tx_context），写法与前面章节中你已经见过的内容类似。关键点在于：函数必须具有正确的函数签名。
在包含这个新函数之后，需要再写一个测试函数，确保它的行为符合预期。

```move
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
```

在新的测试函数中，有几个细节需要注意：

1. **创建测试用户地址**
   代码首先会创建一些地址，代表参与该测试场景的用户。

2. **开启第一个交易**
   测试接着通过 **初始剑的持有者** 发起第一笔交易，建立一个测试场景（scenario）。

3. **进行下一笔交易**
   初始持有者执行第二笔交易（通过 `test_scenario::next_tx` 函数传入）。在这笔交易里，用户会把他们拥有的剑转移给最终持有者。

在纯 Move 环境下是没有 **Sui 存储** 概念的，因此无法轻易地在模拟交易中从存储中取出对象。这就是 `test_scenario` 模块的作用 —— 其中的 `take_from_sender` 函数可以让当前交易中执行者地址下的某个对象（例如 `Sword`）被取出，供 Move 代码使用。
这里假设用户地址下只有一个该类型的对象。在测试代码中，就是通过从存储中取出的 `Sword` 对象，将其转移到另一个地址。

> 在 Sui 的测试场景中，**交易效果（如对象创建和转移）只有在该笔交易完成后才会生效**。
> 举个例子：
   * 如果在第二笔交易中创建了一把剑，并立即将它转移到管理员的地址；
   * 那么在这一笔交易执行完成之前，管理员地址下并不会真正拥有这把剑；
   * 换句话说，这个对象要等到 **第三笔交易** 执行时，才能通过 `test_scenario` 提供的 `take_from_sender` 或 `take_from_address` 等函数，从管理员地址中取出来供 Move 代码操作。
   👉 这点很重要，因为它体现了 **Sui 事务的原子性和可见性规则**：交易的所有状态变更都在交易结束后一次性提交，只有提交后其他交易才能看到这些变更。

在第三笔、也是最后一笔交易中，**最终持有者** 会从存储中取出剑对象，并检查它是否具备预期的属性。

需要注意的是：

* 在 **纯 Move 测试场景** 中，一旦某个对象（如剑）在 Move 代码里被创建或从模拟存储中取出，就不能凭空“消失”。
* 在这种情况下，通常的做法是将对象转移到一个“假地址”（fake address），来解决对象无法消失的问题。

而在 **Sui 的 test_scenario 包** 里，则提供了更优雅、也更贴近 Sui 实际执行逻辑的解决方案：

* 可以通过 `test_scenario::return_to_sender` 函数，把对象重新放回对象池。这样对象不会消失，而是像真实交易执行一样回到存储。

另外，如果测试场景中并不希望返回给发送者，或者你确实想销毁对象，`test_utils` 模块还提供了一个通用的 `destroy<T>` 函数，可以对任意类型 `T` 使用，不受其能力约束。

👉 建议你也可以去看看 `test_scenario` 和 `test_utils` 模块中提供的其他实用函数，它们能帮你写出更贴近实际的 Sui 测试。

最后，再次运行测试命令，你应该就能看到这个模块下的 **两个测试用例全部成功通过** ✅。

```
INCLUDING DEPENDENCY Bridge
INCLUDING DEPENDENCY SuiSystem
INCLUDING DEPENDENCY Sui
INCLUDING DEPENDENCY MoveStdlib
BUILDING my_first_package
Running Move unit tests
[ PASS    ] my_first_package::example::test_sword_create
[ PASS    ] my_first_package::example::test_sword_transactions
Test result: OK. Total tests: 2; passed: 2; failed: 0
```

### 4.3 模块初始化函数

在一个包（package）中，每个模块都可以包含一个 **特殊的初始化函数（init）**，它会在模块发布时执行。

**初始化函数的作用**：用于预先初始化模块相关的数据，例如创建单例对象。

要让初始化函数在发布时执行，它必须满足以下条件：

1. **函数名必须为 `init`**
2. **参数列表必须以 `&mut TxContext` 或 `&TxContext` 结尾**
3. **不能有返回值**
4. **可见性为私有（private）**
5. 可选：参数列表开头可以接受模块的一次性见证（one-time witness）值。更多信息可参考《The Move Book》中的 One Time Witness 章节。

例如，以下 `init` 函数都是合法的写法：

```move
fun init(ctx: &TxContext)
fun init(ctx: &mut TxContext)
fun init(otw: EXAMPLE, ctx: &TxContext)
fun init(otw: EXAMPLE, ctx: &mut TxContext)
```

虽然 `sui move` 命令不支持显式发布模块，但你仍然可以通过测试框架来验证 **模块初始化函数**：方法是将 **第一笔交易专门用于执行初始化函数**。

在当前示例中，模块的 `init` 函数会创建一个 **Forge 对象**。

```move
fun init(ctx: &mut TxContext) {
    let admin = Forge {
        id: object::new(ctx),
        swords_created: 0,
    };

    transfer::transfer(admin, ctx.sender());
}
```
到目前为止，你的测试确实调用了 `init` 函数，但**并没有真正验证初始化函数是否正确创建了 Forge 对象**。

为了测试这部分功能，你可以做以下修改：

1. **新增一个 `new_sword` 函数**

   * 接收 Forge 对象作为参数
   * 在函数末尾更新 Forge 中记录的已创建剑数量

2. **替换逻辑（可选）**

   * 如果这是实际模块，你本来可以用 `new_sword` 直接替代 `sword_create`
   * 为了避免现有测试失败，目前保持两个函数同时存在

这样，`init` 函数创建的 Forge 对象就可以被 `new_sword` 使用，同时你也可以编写测试来验证 Forge 对象是否正确维护了创建的剑数量。

```move
public fun new_sword(forge: &mut Forge, magic: u64, strength: u64, ctx: &mut TxContext): Sword {
    forge.swords_created = forge.swords_created + 1;
    Sword {
        id: object::new(ctx),
        magic: magic,
        strength: strength,
    }
}
```
现在，创建一个函数来测试模块初始化：

```move
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
```

在新的测试函数中，流程如下：

1. **第一笔交易**

   * 显式调用模块的 **initializer** 函数。

2. **第二笔交易**

   * 检查 Forge 对象是否已经创建并正确初始化。

3. **第三笔交易**

   * 管理员使用 Forge 创建一把剑，并将其转移给初始持有者。

这样就完整地测试了 **初始化函数的效果**、**Forge 对象状态** 以及 **剑创建和转移逻辑**。

你可以参考 `sui/examples` 目录下 `first_package` 模块的源代码，里面包含了所有函数和测试的完整实现，并且都已正确调整。

完整示例代码见：https://github.com/vsiryxm/my_first_package.git


## 五、部署合约
```bash
$ sui client publish --gas-budget 5000000
```
> 从 Sui v1.24.1 起 CLI 在某些命令下不再强制要求 --gas-budget 选项。

如果发布交易成功，你在终端应该会看到以下信息：交易数据、交易效果、交易块事件、对象更改和余额更改。
```
Transaction Digest: 6sUstUCS2NvwrrgUPFM5i3Vqun78bGtRUUYYmT9XK6d9
......
╭────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Object Changes                                                                                     │
├────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Created Objects:                                                                                   │
│ ......                                                                                             │
│ Mutated Objects:                                                                                   │
│ ......                                                                                             │
│ Published Objects:                                                                                 │
│  ┌──                                                                                               │
│  │ PackageID: 0xc7eb7c7afae8849241dda48bf89bceb6e7c35f73619e2613267e66d2adccd038                   │
│  │ Version: 1                                                                                      │
│  │ Digest: CAvCmmBk4erTbwkmRSUkUEJhxrtV3x5Xfb8e4MCN8RrE                                            │
│  │ Modules: example                                                                                │
│  └──                                                                                               │
╰────────────────────────────────────────────────────────────────────────────────────────────────────╯
```

建议记录一下关键信息以备后用：
```
PackageID: 0xc7eb7c7afae8849241dda48bf89bceb6e7c35f73619e2613267e66d2adccd038 // 即合约地址
UpgradeCap: 0xb6957e69853ebe8129b7e2fd3939381d17091ec75b73770b069a8acebdb6eeb0
```

你当前活跃的地址现在有三个对象，如下：（假设你使用的是新地址）

```
$ sui client objects
╭───────────────────────────────────────────────────────────────────────────────────────╮
│ ╭────────────┬──────────────────────────────────────────────────────────────────────╮ │
│ │ objectId   │  0x330b5111c8f4a24b25369c4f8f9379210abe8e13f7fa43b9f9e3c93a728257cb  │ │
│ │ version    │  71                                                                  │ │
│ │ digest     │  deHkRcQphCgAqO5sXLbTS5lGT7rL9EVYWPm4cBoNVpc=                        │ │
│ │ objectType │  0xc7eb..d038::example::Forge                                        │ │
│ ╰────────────┴──────────────────────────────────────────────────────────────────────╯ │
│ ╭────────────┬──────────────────────────────────────────────────────────────────────╮ │
│ │ objectId   │  0x5dee4a8b67efca75be1d8ad3dbe0e94f95412946dd7b1be15dd96d357ddfd2e1  │ │
│ │ version    │  71                                                                  │ │
│ │ digest     │  9VRwhADBEdzAloNj0ja0hSWIjbwZNmjPFfj1juLdkZw=                        │ │
│ │ objectType │  0x0000..0002::coin::Coin                                            │ │
│ ╰────────────┴──────────────────────────────────────────────────────────────────────╯ │
│ ╭────────────┬──────────────────────────────────────────────────────────────────────╮ │
│ │ objectId   │  0xb6957e69853ebe8129b7e2fd3939381d17091ec75b73770b069a8acebdb6eeb0  │ │
│ │ version    │  71                                                                  │ │
│ │ digest     │  jYC4GDQVeXzejNBYxjT7FMy129EZTWq7JJayr1DkJSw=                        │ │
│ │ objectType │  0x0000..0002::package::UpgradeCap                                   │ │
│ ╰────────────┴──────────────────────────────────────────────────────────────────────╯ │
╰───────────────────────────────────────────────────────────────────────────────────────╯
```
该objectId字段是每个对象的唯一标识符。
- Coin对象：你从测试网水龙头收到了 Coin 对象。
- Forge对象：回想一下，该init函数在包发布时运行。该init函数会创建一个Forge对象并将其转移给合约部署者（你）。
- UpgradeCap对象：你发布的每个合约都会收到一个UpgradeCap对象。你可以使用此对象升级合约，也可以销毁该对象使合约无法升级。


## 六、与合约交互

例如，可以通过调用 example 包中的 new_sword 函数创建一个新的 Sword 对象，然后将该 Sword 对象转移到任意地址。

```bash
$ sui client ptb \
	--assign forge @<FORGE-ID> \
	--assign to_address @<TO-ADDRESS> \
	--move-call <PACKAGE-ID>::example::new_sword forge 3 3 \
	--assign sword \
	--transfer-objects "[sword]" to_address \
	--gas-budget 20000000
```

> 你可以通过字符串地址和对象 ID 前添加“@”前缀来传递它们。在某些情况下，这是为了区分十六进制值和地址。
> 对于本地的钱包地址，你可以使用它们的别名（传递它们时不用加“@”，如 --transfer-objects "[sword]" my_wallet_alias）。
> 根据 shell 和操作系统，你可能需要传递一些带有引号（“）的值，如 --assign “forge @<FORGE-ID>”。

确保将 <FORGE-ID>、<TO-ADDRESS> 和 <PACKAGE-ID> 分别替换为 Forge 对象的实际 objectId、收件人的地址（在本例中为你当前激活的地址）和合约的 packageID：

```bash
$ sui client ptb \
  --assign forge @0x330b5111c8f4a24b25369c4f8f9379210abe8e13f7fa43b9f9e3c93a728257cb \
  --assign to_address @0xffff5527c9b0e8119c64a6541c7c68eb9bf51a205183127fafbef5e422b1c9c1 \
  --move-call 0xc7eb7c7afae8849241dda48bf89bceb6e7c35f73619e2613267e66d2adccd038::example::new_sword forge 3 3 \
  --assign sword \
  --transfer-objects "[sword]" to_address \
  --gas-budget 20000000

Transaction Digest: G3eihUpmVBq75HovbNSxpVoctXKKMH7SmArfyvdpAwmJ
......
```
这条 PTB 的逻辑是：
指向一个已存在的 Forge（forge），调用 new_sword(forge, 3, 3) 创建一把 Sword 并把返回值保存为 sword，然后把 sword 转移到 to_address，整个过程使用给定的 gas 预算执行。
`0xffff5527c9b0e8119c64a6541c7c68eb9bf51a205183127fafbef5e422b1c9c1` 为当前激活账号。

交易执行完成后，你可以再次使用 `sui client objects` 命令检查 Sword 对象的状态。假设你使用自己的地址作为 <TO-ADDRESS>，现在应该可以看到总共四个对象：

```
$ sui client objects
╭───────────────────────────────────────────────────────────────────────────────────────╮
│ ╭────────────┬──────────────────────────────────────────────────────────────────────╮ │
│ │ objectId   │  0x330b5111c8f4a24b25369c4f8f9379210abe8e13f7fa43b9f9e3c93a728257cb  │ │
│ │ version    │  78                                                                  │ │
│ │ digest     │  22piEqWrt+IcelvKP6j1C6MM4XzvE6cFvnJ30X2VAJ0=                        │ │
│ │ objectType │  0xc7eb..d038::example::Forge                                        │ │
│ ╰────────────┴──────────────────────────────────────────────────────────────────────╯ │
│ ╭────────────┬──────────────────────────────────────────────────────────────────────╮ │
│ │ objectId   │  0x5dee4a8b67efca75be1d8ad3dbe0e94f95412946dd7b1be15dd96d357ddfd2e1  │ │
│ │ version    │  78                                                                  │ │
│ │ digest     │  jS0OfIBQLlotxQfZef4jNBCRoczo2g4L5iuPajql2jQ=                        │ │
│ │ objectType │  0x0000..0002::coin::Coin                                            │ │
│ ╰────────────┴──────────────────────────────────────────────────────────────────────╯ │
│ ╭────────────┬──────────────────────────────────────────────────────────────────────╮ │
│ │ objectId   │  0x6df690a735c3431dae8dcff48c634547bb5b8d017329fb31713854877b9e35e4  │ │
│ │ version    │  78                                                                  │ │
│ │ digest     │  B3HR/QP5eyKNIweo8dCxms2om5XffbCCZ1TKJfcEv+Y=                        │ │
│ │ objectType │  0xc7eb..d038::example::Sword                                        │ │
│ ╰────────────┴──────────────────────────────────────────────────────────────────────╯ │
│ ╭────────────┬──────────────────────────────────────────────────────────────────────╮ │
│ │ objectId   │  0xb6957e69853ebe8129b7e2fd3939381d17091ec75b73770b069a8acebdb6eeb0  │ │
│ │ version    │  71                                                                  │ │
│ │ digest     │  jYC4GDQVeXzejNBYxjT7FMy129EZTWq7JJayr1DkJSw=                        │ │
│ │ objectType │  0x0000..0002::package::UpgradeCap                                   │ │
│ ╰────────────┴──────────────────────────────────────────────────────────────────────╯ │
╰───────────────────────────────────────────────────────────────────────────────────────╯
```

## 七、调试合约

Move 目前没有原生调试器。不过，你可以使用 std::debug 模块，将任意值打印到控制台，从而监控变量值并了解模块的逻辑。

首先，在源文件中为 debug 模块声明一个别名，以便更简洁地访问：
```move
use std::debug;
```
然后在你想要打印出值 `v` 的地方，无论其类型如何，添加以下代码：
```move
debug::print(&v);
```
或者如果 `v` 已经是一个引用，则执行以下命令：
```move
debug::print(v);
```
调试模块还提供了打印当前堆栈跟踪的功能：
```move
debug::print_stack_trace();
```
或者，任何中止或断言失败的调用也会在失败点打印堆栈跟踪。

回到 example.move，在代码的开头引入：
```move
use std::debug;
```

以调试 `new_sword` 为例，在终端打印出 `forge` 的值，也可以打印堆栈跟踪信息：
```move
public fun new_sword(forge: &mut Forge, magic: u64, strength: u64, ctx: &mut TxContext): Sword {
    debug::print(forge); // 调试打印
    forge.swords_created = forge.swords_created + 1;
    debug::print(forge); // 调试打印
    debug::print_stack_trace(); // 调试打印：堆栈跟踪信息
    Sword {
        id: object::new(ctx),
        magic: magic,
        strength: strength,
    }
}
```

运行`sui move test`看看效果，当测试调用 `new_sword` 函数时，你会看到：

```bash
$ sui move test
INCLUDING DEPENDENCY Bridge
INCLUDING DEPENDENCY SuiSystem
INCLUDING DEPENDENCY Sui
INCLUDING DEPENDENCY MoveStdlib
BUILDING my_first_package
Running Move unit tests
[debug] 0x0::example::Forge {
  id: 0x2::object::UID {
    id: 0x2::object::ID {
      bytes: @0x34401905bebdf8c04f3cd5f04f442a39372c8dc321c29edfb4f9cb30b23ab96
    }
  },
  swords_created: 0
}
[debug] 0x0::example::Forge {
  id: 0x2::object::UID {
    id: 0x2::object::ID {
      bytes: @0x34401905bebdf8c04f3cd5f04f442a39372c8dc321c29edfb4f9cb30b23ab96
    }
  },
  swords_created: 1
}
Call Stack:
    [0] 0000000000000000000000000000000000000000000000000000000000000000::example::test_module_init

        Code:
            [35] LdU64(7)`
            [36] MutBorrowLoc(3)
            [37] Call(15)
          > [38] Call(5)
            [39] LdConst(0)
            [40] CallGeneric(2)
            [41] ImmBorrowLoc(3)

        Locals:
            [0] -
            [1] -
            [2] { { { 034401905bebdf8c04f3cd5f04f442a39372c8dc321c29edfb4f9cb30b23ab96 } }, 1 }
            [3] { 2, { 0000000000000000000000000000000000000000000000000000000000000000, [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 0, 0, 0 } }


Operand Stack:

[ PASS    ] my_first_package::example::test_module_init
[ PASS    ] my_first_package::example::test_sword_create
[ PASS    ] my_first_package::example::test_sword_transactions
Test result: OK. Total tests: 3; passed: 3; failed: 0
```
从上述信息可以了解到，`forge` 对象的 `swords_created` 字段值发生了变化。从堆栈跟踪信息中可以看到已执行的字节码指令。


## 参考资料

https://move-book.com/

https://docs.sui.io/guides/developer/first-app

