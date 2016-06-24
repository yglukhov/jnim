import jbridge,
       core

jclass java.util.Collection*[V] of JVMObject:
  proc add*[V](v: V): bool

jclass java.util.List*[V] of Collection[V]:
  proc add*[V](i: jint, v: V)
  proc get*[V](i: jint): V

jclass java.util.ArrayList*[V] of List[V]:
  proc jnew*[V]
