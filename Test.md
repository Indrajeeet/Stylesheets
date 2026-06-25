# DataWeave System Properties — Full Reference

## Memory & Buffer Properties

| Property | Default | Since Mule | Effect |
|----------|---------|-----------|--------|
| `com.mulesoft.dw.buffersize` | 8192 (8 KB) | 4.0 | In-memory I/O buffer per R/W operation. Increase to 65536 for large XML/JSON line reads. |
| `com.mulesoft.dw.max_memory_allocation` | 1,572,864 (~1.5 MB) | 4.0 | Threshold before spilling payload to dw-buffer-*.tmp files. |
| `com.mulesoft.dw.charbuffersize` | 8192 | 4.0 | Writer char buffer. Increase for large string output. |
| `com.mulesoft.dw.directbuffer.disable` | `false` | 4.2.2 | `true` = use heap instead of off-heap. Use on low-memory hosts only. |
| `com.mulesoft.dw.memory_pool_size` | 60 | 4.3.0 | Number of off-heap pool slots. Increase for high concurrency DW loads. |
| `com.mulesoft.dw.buffer.memory.monitoring` | `false` | 4.3.0 | Logs each pool slot acquire/release. **Debug only — high verbosity.** |
| `java.io.tmpdir` | OS default | any | Directory for dw-buffer-*.tmp files. Point to fast ephemeral storage. |

## Script Cache & Compilation

| Property | Default | Since Mule | Effect |
|----------|---------|-----------|--------|
| `mule.weave.script.parser.cache.size` | 10,000 | 4.0 | Max compiled DW scripts cached. Reduce if metaspace pressure observed. |

## Execution Behaviour
