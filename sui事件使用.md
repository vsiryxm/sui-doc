
# 使用事件（Using Events）

在 Sui 网络中，链上存储了大量对象，Move 代码可以使用这些对象执行操作。通常，我们希望追踪这些活动，例如，了解某个模块铸造了多少次 NFT，或统计智能合约生成的交易中涉及的 SUI 数量。

为支持活动监控，Move 提供了一个结构体用于在 Sui 网络上发出事件。您可以利用自定义索引器处理包含已发出事件的检查点数据。有关如何流式传输检查点并持续过滤事件的信息，请参阅高级部分中的[自定义索引器](https://docs.sui.io/guides/developer/advanced/custom-indexer)主题。

如果您不想运行自定义索引器，也可以轮询 Sui 网络以查询已发出的事件。此方法通常包括一个数据库，用于存储从这些调用中检索到的数据。轮询事件部分提供了使用此方法的示例。

### Move 事件结构

Sui 中的事件对象包含以下属性：

* `id`：包含交易摘要 ID 和事件序列的 JSON 对象。
* `packageId`：发出事件的包的对象 ID。
* `transactionModule`：执行交易的模块。
* `sender`：触发事件的 Sui 网络地址。
* `type`：发出的事件类型。
* `parsedJson`：描述事件的 JSON 对象。
* `bcs`：二进制规范化序列化值。
* `timestampMs`：以毫秒为单位的 Unix 纪元时间戳。

### 在 Move 中发出事件

要在 Move 模块中创建事件，请添加 `sui::event` 依赖项。

```move
use sui::event;
```

添加依赖项后，您可以使用 `emit` 函数，在您希望监控的操作触发时发出事件。例如，以下代码是一个示例应用程序的一部分，允许锁定对象。`lock` 函数处理对象的锁定，并在每次调用时发出事件。

参考：[escrow/sources/lock.move](./escrow/sources/lock.move)
```move
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

    dof::add(&mut lock.id, LockedObjectKey {}, obj);

    (lock, key)
}
```

### 使用 RPC 查询事件

Sui RPC 提供了一个 `queryEvents` 方法，用于查询链上包并返回可用的事件。例如，以下 `curl` 命令查询 Mainnet 上 Deepbook 包的特定类型事件：

```bash
$ curl -X POST https://fullnode.mainnet.sui.io:443 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "suix_queryEvents",
    "params": [
      {
        "MoveModule": {
          "package": "0x158f2027f60c89bb91526d9bf08831d27f5a0fcb0f74e6698b9f0e1fb2be5d05",
          "module": "deepbook_utils",
          "type": "0xdee9::clob_v2::DepositAsset<0x5d4b302506645c37ff133b98c4b50a5ae14841659738d6d733d59d0d217a93bf::coin::COIN>"
        }
      },
      null,
      3,
      false
    ]
  }'
```

### 使用 Rust 查询事件

Sui 的示例仓库包含一个代码示例，演示如何使用 `query_events` 函数查询事件。`PACKAGE_ID_CONST` 指向的包存在于 Mainnet 上，因此您可以使用 Cargo 测试此代码。为此，请在本地克隆 `sui-by-example` 仓库，并按照示例 05 的说明进行操作。

```rust
use sui_sdk::{rpc_types::EventFilter, types::Identifier, SuiClientBuilder};
```

### 使用 GraphQL 查询事件

您也可以使用 GraphQL 查询事件，而不是使用 JSON RPC。以下示例查询位于 Sui 仓库中的 `sui-graphql-rpc` crate 中的事件连接。

```graphql
query ByTxSender {
  events(
    first: 1
    filter: {
      sender: "0xdff57c401e125a7e0e06606380560b459a179aacd08ed396d0162d57dbbdadfb"
    }
  ) {
    pageInfo {
      hasNextPage
      endCursor
    }
    nodes {
      sendingModule {
        name
      }
      contents {
        type {
          repr
        }
        json
      }
      sender {
        address
      }
      timestamp
      bcs
    }
  }
}
```

TypeScript SDK 提供了与 Sui GraphQL 服务交互的功能。

### 监控事件

仅发出事件本身并不十分有用，您还需要能够响应这些事件。当您需要监控链上事件时，有两种方法可供选择：

* 集成自定义索引器，利用 Sui 的微数据摄取框架。
* 定期轮询 Sui 网络以查询事件。

使用自定义索引器可以提供接近实时的事件监控，因此在您的项目需要对事件的触发做出即时反应时最为有用。轮询网络则在您监控的事件不常触发或对这些事件的响应不是即时需求时最为有用。以下部分提供了使用此方法的轮询示例。

### 轮询事件

要监控事件，您需要一个数据库来存储检查点数据。Trustless Swap 示例使用 Prisma 数据库存储来自 Sui 网络的检查点数据。数据库通过轮询网络来检索发出的事件填充。

```typescript
import { EventId, SuiClient, SuiEvent, SuiEventFilter } from '@mysten/sui/client';

import { CONFIG } from '../config';
import { prisma } from '../db';
import { getClient } from '../sui-utils';
import { handleEscrowObjects } from './escrow-handler';
import { handleLockObjects } from './locked-handler';

type SuiEventsCursor = EventId | null | undefined;

type EventExecutionResult = {
  cursor: SuiEventsCursor;
  hasNextPage: boolean;
};
```
