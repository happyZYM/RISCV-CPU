# 和经典Tomasulo的关键区别和对设计图的注释：
- 访存操作不单独设置queue，正常通过ReserveStation维护依赖关系（除了寄存器级别的依赖关系外，还依赖于之前的访存操作）
- Memory Adapter会处理内存写操作，确保commit时才会真正写入内存，同时，这会带来内存异步写，减少阻塞效果。（后续可能会在外面套Cache？若有，cache只接受commit后的“正确数据”）
- Reorder Buffer和Reserve Station大小都为8，直接合二为一，并入途中的Contorller统一为一个Central Schedule Unit
- 暂且先不写Prefetch Manager,此时Instruction Queue无意义。优先完成Instruction Cache
- Instruction Queue的大小为64（暂定，视其他模块对主频的影响适当调整），Replacement算法为Tree-PLRU