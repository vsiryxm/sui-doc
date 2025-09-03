
# 使用事件（Using Events）

在 Sui 网络中，链上存储了大量对象，Move 代码可以使用这些对象执行操作。通常，我们希望追踪这些活动，例如，了解某个模块铸造了多少次 NFT，或统计智能合约生成的交易中涉及的 SUI 数量。

为支持活动监控，Move 提供了一个结构体用于在 Sui 网络上发出事件。你可以利用自定义索引器处理包含已发出事件的检查点数据。有关如何流式传输检查点并持续过滤事件的信息，请参阅高级部分中的[自定义索引器](https://docs.sui.io/guides/developer/advanced/custom-indexer)主题。

如果你不想运行自定义索引器，也可以轮询 Sui 网络以查询已发出的事件。此方法通常包括一个数据库，用于存储从这些调用中检索到的数据。[轮询事件](https://docs.sui.io/guides/developer/sui-101/using-events#poll-events)部分提供了使用此方法的示例。

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

添加依赖项后，你可以使用 `emit` 函数，在你希望监控的操作触发时发出事件。例如，以下代码是一个示例应用程序的一部分，允许锁定对象。`lock` 函数处理对象的锁定，并在每次调用时发出事件。

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

Sui RPC 提供了一个 [queryEvents](https://docs.sui.io/sui-api-ref#suix_queryEvents) 方法，用于查询链上包并返回可用的事件。例如，以下 `curl` 命令查询 Mainnet 上 Deepbook 包的特定类型事件：

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
返回结果：
```json
{
	"jsonrpc": "2.0",
	"id": 1,
	"result": {
		"data": [{
			"id": {
				"txDigest": "8NB8sXb4m9PJhCyLB7eVH4onqQWoFFzVUrqPoYUhcQe2",
				"eventSeq": "0"
			},
			"packageId": "0x158f2027f60c89bb91526d9bf08831d27f5a0fcb0f74e6698b9f0e1fb2be5d05",
			"transactionModule": "deepbook_utils",
			"sender": "0x8b35e67a519fffa11a9c74f169228ff1aa085f3a3d57710af08baab8c02211b9",
			"type": "0xdee9::clob_v2::WithdrawAsset<0x5d4b302506645c37ff133b98c4b50a5ae14841659738d6d733d59d0d217a93bf::coin::COIN>",
			"parsedJson": {
				"owner": "0x704c8c0d8052be7b5ca7174222a8980fb2ad3cd640f4482f931deb6436902627",
				"pool_id": "0x7f526b1263c4b91b43c9e646419b5696f424de28dda3c1e6658cc0a54558baa7",
				"quantity": "6956"
			},
			"bcsEncoding": "base64",
			"bcs": "f1JrEmPEuRtDyeZGQZtWlvQk3ijdo8HmZYzApUVYuqcsGwAAAAAAAHBMjA2AUr57XKcXQiKomA+yrTzWQPRIL5Md62Q2kCYn",
			"timestampMs": "1691757698019"
		}, {
			"id": {
				"txDigest": "8NB8sXb4m9PJhCyLB7eVH4onqQWoFFzVUrqPoYUhcQe2",
				"eventSeq": "1"
			},
			"packageId": "0x158f2027f60c89bb91526d9bf08831d27f5a0fcb0f74e6698b9f0e1fb2be5d05",
			"transactionModule": "deepbook_utils",
			"sender": "0x8b35e67a519fffa11a9c74f169228ff1aa085f3a3d57710af08baab8c02211b9",
			"type": "0xdee9::clob_v2::OrderFilled<0x2::sui::SUI, 0x5d4b302506645c37ff133b98c4b50a5ae14841659738d6d733d59d0d217a93bf::coin::COIN>",
			"parsedJson": {
				"base_asset_quantity_filled": "0",
				"base_asset_quantity_remaining": "1532800000000",
				"is_bid": false,
				"maker_address": "0x78a1ff467e9c15b56caa0dedfcfbdfe47c0c385f28b05fdc120b2de188cc8736",
				"maker_client_order_id": "1691757243084",
				"maker_rebates": "0",
				"order_id": "9223372036854839628",
				"original_quantity": "1614700000000",
				"pool_id": "0x7f526b1263c4b91b43c9e646419b5696f424de28dda3c1e6658cc0a54558baa7",
				"price": "605100",
				"taker_address": "0x704c8c0d8052be7b5ca7174222a8980fb2ad3cd640f4482f931deb6436902627",
				"taker_client_order_id": "20082022",
				"taker_commission": "0"
			},
			"bcsEncoding": "base64",
			"bcs": "f1JrEmPEuRtDyeZGQZtWlvQk3ijdo8HmZYzApUVYuqdM+QAAAAAAgGZtMgEAAAAAzOqW5IkBAAAAcEyMDYBSvntcpxdCIqiYD7KtPNZA9Egvkx3rZDaQJid4of9GfpwVtWyqDe38+9/kfAw4XyiwX9wSCy3hiMyHNgCznvN3AQAAAAAAAAAAAAAA4P/hZAEAAKw7CQAAAAAAAAAAAAAAAAAAAAAAAAAAAA==",
			"timestampMs": "1691757698019"
		}, {
			"id": {
				"txDigest": "8b3byDuRojHXqmSz16PsyzfdXJEY5nZBGTM23gMsMAY8",
				"eventSeq": "0"
			},
			"packageId": "0x158f2027f60c89bb91526d9bf08831d27f5a0fcb0f74e6698b9f0e1fb2be5d05",
			"transactionModule": "deepbook_utils",
			"sender": "0x8b35e67a519fffa11a9c74f169228ff1aa085f3a3d57710af08baab8c02211b9",
			"type": "0xdee9::clob_v2::OrderFilled<0x2::sui::SUI, 0x5d4b302506645c37ff133b98c4b50a5ae14841659738d6d733d59d0d217a93bf::coin::COIN>",
			"parsedJson": {
				"base_asset_quantity_filled": "700000000",
				"base_asset_quantity_remaining": "0",
				"is_bid": false,
				"maker_address": "0x03b86e93d80b27763ee1fc2c37e285465dff835769de9462d9ad4ebcf46ac6df",
				"maker_client_order_id": "20082022",
				"maker_rebates": "634",
				"order_id": "9223372036854839643",
				"original_quantity": "1000000000",
				"pool_id": "0x7f526b1263c4b91b43c9e646419b5696f424de28dda3c1e6658cc0a54558baa7",
				"price": "604100",
				"taker_address": "0x704c8c0d8052be7b5ca7174222a8980fb2ad3cd640f4482f931deb6436902627",
				"taker_client_order_id": "20082022",
				"taker_commission": "1058"
			},
			"bcsEncoding": "base64",
			"bcs": "f1JrEmPEuRtDyeZGQZtWlvQk3ijdo8HmZYzApUVYuqdb+QAAAAAAgGZtMgEAAAAAZm0yAQAAAAAAcEyMDYBSvntcpxdCIqiYD7KtPNZA9Egvkx3rZDaQJicDuG6T2Asndj7h/Cw34oVGXf+DV2nelGLZrU689GrG3wDKmjsAAAAAACe5KQAAAAAAAAAAAAAAAMQ3CQAAAAAAIgQAAAAAAAB6AgAAAAAAAA==",
			"timestampMs": "1691758372427"
		}],
		"nextCursor": {
			"txDigest": "8b3byDuRojHXqmSz16PsyzfdXJEY5nZBGTM23gMsMAY8",
			"eventSeq": "0"
		},
		"hasNextPage": true
	}
}
```

TypeScript SDK 为该 `suix_queryEvents` 方法提供了一个包装器：[client.queryEvents](https://sdk.mystenlabs.com/typedoc/classes/_mysten_sui.client.SuiClient.html#queryEvents)

**TypeScript SDK queryEvents 示例：**
```typescript
import { useCurrentAccount, useSignAndExecuteTransaction, useSuiClient } from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/transactions";
import { Button, Flex, Heading } from "@radix-ui/themes";

export function Creategame({ onCreated }: { onCreated: (id: string) => void }) {
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();
  const currentAccount = useCurrentAccount();
  const client = useSuiClient();

  const executeMoveCall = async (method: "small" | "large") => {
    if (!currentAccount?.address) {
      console.error("No connected account found.");
      return;
    }

    try {
      const tx = new Transaction();

      tx.moveCall({
        arguments: [tx.pure.u64(method === "small" ? 0 : 1)],
        target: `<PACKAGE-ID>::<MODULE>::create_game`,
      });

      const txResult = await signAndExecute({
        transaction: tx,
      });

      await client.waitForTransaction({
        digest: txResult.digest
      });

      const eventsResult = await client.queryEvents({
        query: { Transaction: txResult.digest },
      });

      if (eventsResult.data.length > 0) {
        const firstEvent = eventsResult.data[0]?.parsedJson as { msg?: string };
        const result = firstEvent?.msg || "No events found for the given criteria.";
        onCreated(result);
      } else {
        onCreated("No events found for the given criteria.");
      }
    } catch (error) {
      console.error("Error creating game or querying events:", error);
    }
  };

  return (
    <>
      <Heading size="3">Game Start</Heading>
      <Flex direction="column" gap="2">
        <Flex direction="row" gap="2">
          <Button onClick={() => executeMoveCall("small")}>small</Button>
          <Button onClick={() => executeMoveCall("large")}>large</Button>
        </Flex>
      </Flex>
    </>
  );
}
```

### 过滤事件查询

要过滤查询返回的事件，请使用以下数据结构：
| 查询                 | 描述 | JSON-RPC参数示例                                                             |
| ------------------- | ---- | -------------------------------------------------------------------- |
| **All**             | 所有事件    | `{"All": []}`                                                                    |
| **Any**             | 从任何给定过滤器发出的事件    | `{"Any": [filters...]}`                                           |
| **Transaction**     | 从指定交易发出的事件    | `{"Transaction":"<tx_digest>"}`                                        |
| **MoveModule**      | 从指定的 Move 模块发出的事件   | `{"MoveModule":{"package":"<PKG>","module":"<MOD>"}}`           |
| **MoveEventModule** | 发出的事件，在指定的 Move 模块上定义 | `{"MoveEventModule":{"package":"<PKG>","module":"<MOD>"}}` |
| **MoveEventType**   | Move 事件的结构名称 | `{"MoveEventType":"::nft::MintNFTEvent"}`                                 |
| **Sender**          | 按发件人地址查询 | `{"Sender":"0x...address..."}`                                                |
| **TimeRange**       | 返回在 [start_time, end_time] 间隔内发出的事件 | `{"TimeRange":{"startTime":1669039504014, "endTime":1669039604014}}` |


### 使用 Rust 查询事件

[Sui 的示例仓库](https://github.com/gdanezis/sui-by-example/blob/main/src/05_reading_events/bin/main.rs)包含一个代码示例，演示如何使用 `query_events` 函数查询事件。`PACKAGE_ID_CONST` 指向的包存在于 Mainnet 上，因此你可以使用 Cargo 测试此代码。为此，请在本地克隆 `sui-by-example` 仓库，并按照[示例 05 ](https://github.com/gdanezis/sui-by-example/tree/main/src/05_reading_events)的说明进行操作。

```rust
use sui_sdk::{rpc_types::EventFilter, types::Identifier, SuiClientBuilder};

const PACKAGE_ID_CONST: &str = "0x279525274aa623ef31a25ad90e3b99f27c8dbbad636a6454918855c81d625abc";

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    let sui_mainnet = SuiClientBuilder::default()
        .build("https://fullnode.mainnet.sui.io:443")
        .await?;

    let events = sui_mainnet
        .event_api()
        .query_events(
            EventFilter::MoveModule {
                package: PACKAGE_ID_CONST.parse()?,
                module: Identifier::new("dev_trophy")?,
            },
            None,
            None,
            false,
        )
        .await?;

    for event in events.data {
        println!("Event: {:?}", event.parsed_json);
    }

    Ok(())
}
```

### 使用 GraphQL 查询事件

你也可以使用 GraphQL 查询事件，而不是使用 JSON RPC。以下示例查询位于 Sui 仓库中的 [sui-graphql-rpc crate](https://github.com/MystenLabs/sui/tree/main/crates/sui-graphql-rpc/examples/event_connection) 中的事件连接。

参考：[crates/sui-graphql-rpc/examples/event_connection/event_connection.graphql](https://github.com/MystenLabs/sui/blob/main/crates/sui-graphql-rpc/examples/event_connection/event_connection.graphql)

```graphql
{
  events(
    filter: {
      eventType: "0x3164fcf73eb6b41ff3d2129346141bd68469964c2d95a5b1533e8d16e6ea6e13::Market::ChangePriceEvent<0x2::sui::SUI>"
    }
  ) {
    nodes {
      sendingModule {
        name
        package { digest }
      }
      sender {
        address
      }
      timestamp
      contents {
        type {
          repr
        }
        json
      }
      bcs
    }
  }
}
```

参考：[crates/sui-graphql-rpc/examples/event_connection/filter_by_sender.graphql](https://github.com/MystenLabs/sui/blob/main/crates/sui-graphql-rpc/examples/event_connection/filter_by_sender.graphql)
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

[TypeScript SDK](https://sdk.mystenlabs.com/typedoc/modules/_mysten_sui.graphql.html) 提供了与 Sui GraphQL 服务交互的功能。

### 监控事件

仅发出事件本身并不十分有用，你还需要能够响应这些事件。当你需要监控链上事件时，有两种方法可供选择：

* 集成[自定义索引器](https://docs.sui.io/guides/developer/advanced/custom-indexer)，利用 Sui 的微数据摄取框架。
* 定期轮询 Sui 网络以查询事件。

使用自定义索引器可以实现近乎实时的事件监控，因此当你的项目需要对事件的触发做出立即反应时，它非常有用。
当你监控的事件不经常触发，或者不需要立即对这些事件采取行动时，轮询网络最为有用。以下部分提供了一个轮询示例。

### 轮询事件

要监控事件，你需要一个数据库来存储检查点数据。[Trustless Swap](https://docs.sui.io/guides/developer/app-examples/trustless-swap) 示例使用 Prisma 数据库存储来自 Sui 网络的检查点数据。数据库通过轮询网络来检索发出的事件填充。

参考：[examples/trading/api/indexer/event-indexer.ts](https://github.com/MystenLabs/sui/blob/main/examples/trading/api/indexer/event-indexer.ts)
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

type EventTracker = {
  type: string;
  filter: SuiEventFilter;
  callback: (events: SuiEvent[], type: string) => any;
};

const EVENTS_TO_TRACK: EventTracker[] = [
  {
    type: `${CONFIG.SWAP_CONTRACT.packageId}::lock`,
    filter: {
      MoveEventModule: {
        module: 'lock',
        package: CONFIG.SWAP_CONTRACT.packageId,
      },
    },
    callback: handleLockObjects,
  },
  {
    type: `${CONFIG.SWAP_CONTRACT.packageId}::shared`,
    filter: {
      MoveEventModule: {
        module: 'shared',
        package: CONFIG.SWAP_CONTRACT.packageId,
      },
    },
    callback: handleEscrowObjects,
  },
];

const executeEventJob = async (
  client: SuiClient,
  tracker: EventTracker,
  cursor: SuiEventsCursor,
): Promise<EventExecutionResult> => {
  try {
    const { data, hasNextPage, nextCursor } = await client.queryEvents({
      query: tracker.filter,
      cursor,
      order: 'ascending',
    });

    await tracker.callback(data, tracker.type);

    if (nextCursor && data.length > 0) {
      await saveLatestCursor(tracker, nextCursor);

      return {
        cursor: nextCursor,
        hasNextPage,
      };
    }
  } catch (e) {
    console.error(e);
  }
  return {
    cursor,
    hasNextPage: false,
  };
};

const runEventJob = async (client: SuiClient, tracker: EventTracker, cursor: SuiEventsCursor) => {
  const result = await executeEventJob(client, tracker, cursor);

  setTimeout(
    () => {
      runEventJob(client, tracker, result.cursor);
    },
    result.hasNextPage ? 0 : CONFIG.POLLING_INTERVAL_MS,
  );
};

/**
 * 获取事件跟踪器的最新游标，可以从数据库（如果未定义）或正在运行的游标中获取
 */
const getLatestCursor = async (tracker: EventTracker) => {
  const cursor = await prisma.cursor.findUnique({
    where: {
      id: tracker.type,
    },
  });

  return cursor || undefined;
};

/**
 * 将事件跟踪器的最新cursor保存到数据库，以便我们可以从那里恢复 
 * */
const saveLatestCursor = async (tracker: EventTracker, cursor: EventId) => {
  const data = {
    eventSeq: cursor.eventSeq,
    txDigest: cursor.txDigest,
  };

  return prisma.cursor.upsert({
    where: {
      id: tracker.type,
    },
    update: data,
    create: { id: tracker.type, ...data },
  });
};

export const setupListeners = async () => {
  for (const event of EVENTS_TO_TRACK) {
    runEventJob(getClient(CONFIG.NETWORK), event, await getLatestCursor(event));
  }
};
```

Trustless Swap 集成了处理程序来处理触发的每种事件类型。对于 `locked` 事件，`locked-handler.ts` 中的处理程序会触发并相应地更新 Prisma 数据库。

参考：[examples/trading/api/indexer/locked-handler.ts](https://github.com/MystenLabs/sui/blob/main/examples/trading/api/indexer/locked-handler.ts)

```rust
import { SuiEvent } from '@mysten/sui/client';
import { Prisma } from '@prisma/client';

import { prisma } from '../db';

type LockEvent = LockCreated | LockDestroyed;

type LockCreated = {
  creator: string;
  lock_id: string;
  key_id: string;
  item_id: string;
};

type LockDestroyed = {
  lock_id: string;
};

/**
 * 处理 `lock` 模块发出的所有事件。
 * 数据建模的方式允许以任意顺序（DESC or ASC）写入数据库，而不会导致数据不一致。
 * 我们正在构建更新，以支持涉及单个记录的多个事件作为同一批事件的一部分（但使用单个写入/记录到数据库）。
 * */
export const handleLockObjects = async (events: SuiEvent[], type: string) => {
  const updates: Record<string, Prisma.LockedCreateInput> = {};

  for (const event of events) {
    if (!event.type.startsWith(type)) throw new Error('Invalid event module origin');
    const data = event.parsedJson as LockEvent;
    const isDeletionEvent = !('key_id' in data);

    if (!Object.hasOwn(updates, data.lock_id)) {
      updates[data.lock_id] = {
        objectId: data.lock_id,
      };
    }

    // 处理deletion事件
    if (isDeletionEvent) {
      updates[data.lock_id].deleted = true;
      continue;
    }

    // 处理creation事件
    updates[data.lock_id].keyId = data.key_id;
    updates[data.lock_id].creator = data.creator;
    updates[data.lock_id].itemId = data.item_id;
  }

  // 作为演示的一部分，为了避免外部依赖，我们使用 SQLite 作为数据库 
  // Prisma + SQLite 不支持批量插入和冲突处理，因此我们必须逐个插入（导致多次往返数据库） 
  // 在生产数据库（例如 Postgres）中，始终使用单个 `bulkInsert` 查询并进行适当的 `onConflict` 处理 
  const promises = Object.values(updates).map((update) =>
    prisma.locked.upsert({
      where: {
        objectId: update.objectId,
      },
      create: {
        ...update,
      },
      update,
    }),
  );
  await Promise.all(promises);
};
```

### 相关链接
- [Custom Indexer](https://docs.sui.io/guides/developer/advanced/custom-indexer)：为了近乎实时地监控事件，你可以使用自定义索引器。 
- [Events](https://move-book.com/programmability/events/)：Move 手册展示了如何在 Move 中发出事件。 
- [Trustless Swap](https://docs.sui.io/guides/developer/app-examples/trustless-swap)：无信任交换指南使用事件来更新其前端的状态。