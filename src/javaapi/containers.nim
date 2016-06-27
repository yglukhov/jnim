import jnim, core

jclass java.util.Iterator*[V] of Object:
  proc hasNext*: bool
  proc next*: V
  proc remove*
  
jclass java.util.Collection*[V] of Object:
  proc add*(v: V): bool
  proc addAll*(c: Collection[V]): bool
  proc clear*
  proc contains*(o: JVMObject): bool
  proc isEmpty*: bool
  proc toIterator*: Iterator[V] {.importc: "iterator".}
  proc remove*(o: V): bool
  proc removeAll*(o: Collection[V]): bool
  proc retainAll*(o: Collection[V]): bool
  proc size*: jint

jclass java.util.List*[V] of Collection[V]:
  proc add*(i: jint, v: V)
  proc get*(i: jint): V
  proc set*(i: jint): V
  proc remove*(i: jint)
  proc subList*(f, t: jint): List[V]

jclass java.util.ArrayList*[V] of List[V]:
  proc new*

proc new*[V](t: typedesc[ArrayList[V]], c: openArray[V]): ArrayList[V] =
  result = ArrayList[V].new
  for v in c:
    discard result.add(v)

jclassDef java.util.Set*[E] of Collection[E]

jclass java.util.Map$Entry*[K,V] as MapEntry of Object:
  proc getKey*: K
  proc getValue*: V
  proc setValue*(v: V): V

jclass java.util.Map*[K,V] of Object:
  proc clear*
  proc containsKey*(k: K): bool
  proc containsValue*(k: K): bool
  proc entrySet*: Set[MapEntry[K,V]]
  proc get*(k: K): V
  proc isEmpty*: bool
  proc keySet*: Set[K]
  proc put*(k: K, v: V): V
  proc putAll*(m: Map[K,V])
  proc remove*(k: K): V
  proc size*: jint
  proc values*: Collection[V]

jclass java.util.HashMap*[K,V] of Map[K,V]:
  proc new*

#################################################################################################### 
# Helpers

proc toSeq*[V](c: Collection[V]): seq[V] =
  result = newSeq[V]()
  let it = c.toIterator
  while it.hasNext:
    result.add it.next

