import jbridge,
       core

jclass java.util.Iterator*[V] of JVMObject:
  proc hasNext*[V]: bool
  proc next*[V]: V
  proc remove*[V]
  
jclass java.util.Collection*[V] of JVMObject:
  proc add*[V](v: V): bool
  proc addAll*[V](c: Collection[V]): bool
  proc clear*[V]
  proc contains*[V](o: JVMObject): bool
  proc hasCode*[V]: jint
  proc isEmpty*[V]: bool
  proc toIterator*[V]: Iterator[V] {.importc: "iterator".}
  proc remove*[V,U](o: U): bool
  proc removeAll*[V,U](o: Collection[U]): bool
  proc retainAll*[V,U](o: Collection[U]): bool
  proc size*[V]: jint

jclass java.util.List*[V] of Collection[V]:
  proc add*[V](i: jint, v: V)
  proc get*[V](i: jint): V
  proc set*[V](i: jint): V
  proc remove*[V](i: jint)
  proc subList*[V](f, t: jint): List[V]

jclass java.util.ArrayList*[V] of List[V]:
  proc new*[V]

proc new*[V](t: typedesc[ArrayList[V]], c: openArray[V]): ArrayList[V] =
  result = ArrayList[V].new
  for v in c:
    discard result.add(v)

#################################################################################################### 
# Helpers

proc toSeq*[V](c: Collection[V]): seq[V] =
  result = newSeq[V]()
  let it = c.toIterator
  while it.hasNext:
    result.add it.next

