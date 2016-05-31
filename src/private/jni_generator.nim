import jni_api,
       strutils,
       macros

type
  ProcDef* = object
    name*: string
    jName*: string
    sig*: string
    isConstructor*: bool
    isStatic*: bool
    isProp*: bool
    isExported*: bool
    
proc initProcDef(name: string, jName: string, sig: string, isConstructor, isStatic, isProp, isExported: bool): ProcDef =
  ProcDef(name: name, jName: jName, sig: sig, isConstructor: isConstructor, isStatic: isStatic, isProp: isProp, isExported: isExported)

const IdentPos = 0
const ParamsPos = 3

proc concat(s: varargs[string]): string = "(" & s.join() & ")"

proc getProcSignature*(n: NimNode): NimNode {.compileTime.} =
  expectKind n, nnkFormalParams
  let hasRet = n.len > 0 and n[0].kind == nnkIdent
  let hasParams = n.len > 1

  let ret = if hasRet: newCall("jniSig", n[0]) else: "V".newStrLitNode

  var params = newCall(bindSym("concat"))
  if hasParams:
    for i in 1..<n.len:
      params.add(newCall("jniSig", n[i][1]))
  
  result = quote do:
    `params` & `ret`

macro procSig*(v: untyped, e: expr): stmt =
  # Allow to use in tests
  let n = if e.kind == nnkStmtList: e[0] else: e
  expectKind n, nnkProcDef
  expectKind n[IdentPos], {nnkIdent, nnkPostfix}
  let i = newIdentNode($v)
  let r = getProcSignature(n[ParamsPos])
  result = quote do:
    let `i` = `r`

proc parseProcDef(n: NimNode, def: NimNode): NimNode {.compileTime.} =
  result = newStmtList()
  expectKind n, nnkProcDef
  expectKind n[IdentPos], {nnkIdent, nnkPostfix}

  var name,
      jName,
      sig,
      isConstructor,
      isStatic,
      isProp,
      isExported : NimNode

  if n[IdentPos].kind == nnkPostfix:
    assert $n[IdentPos][0].toStrLit == "*"
    name = newStrLitNode($n[IdentPos][1])
    isExported = bindSym"true"
  else:
    name = newStrLitNode($n[IdentPos])
    isExported = bindSym"false"
  expectKind n[ParamsPos], nnkFormalParams

  # Check constructor by name
  if $name == "new":
    jName = newStrLitNode("<init>")
    isConstructor = bindSym"true"
  else:
    jName = name.copyNimNode
    isConstructor = bindSym"false"

  sig = getProcSignature(n[ParamsPos])

  isStatic = bindSym"false"
  isProp = bindSym"false"

  result.add quote do:
    `def` = initProcDef(`name`, `jName`, `sig`, `isConstructor`,  `isStatic`, `isProp`, `isExported`)

macro parseProcDefTest*(i: untyped, s: expr): stmt =
  result = parseProcDef(s[0], i)

macro jclass*(head: expr, body: expr): stmt =
  echo "HEAD:"
  echo head.treeRepr
  echo "BODY:"
  for son in body:
    echo treeRepr(son)
    # echo parseProcDef(son)
  result = newStmtList()
