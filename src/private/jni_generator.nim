import jni_api,
       strutils,
       macros,
       fp.option

proc concat(s: varargs[string]): string = "(" & s.join() & ")"

proc nodeToString(n: NimNode): string =
  if n.kind == nnkIdent:
    result = $n
  elif n.kind == nnkAccQuoted:
    result = ""
    for s in n:
      result &= s.nodeToString
  elif n.kind == nnkStrLit:
    result = n.strVal
  elif n.kind == nnkDotExpr:
    result = n[0].nodeToString & "." & n[1].nodeToString
  elif n.kind == nnkInfix and n[0].nodeToString == "$":
    result = n[1].nodeToString & "$" & n[2].nodeToString
  else:
    assert false, "Can't stringify " & $n.kind

#################################################################################################### 
# Proc signature parser 

type
  ProcDef* = object
    name*: string
    jName*: string
    sig*: string
    isConstructor*: bool
    isStatic*: bool
    isProp*: bool
    isFinal*: bool
    isExported*: bool
    
proc initProcDef(name: string, jName: string, sig: string, isConstructor, isStatic, isProp, isFinal, isExported: bool): ProcDef =
  ProcDef(name: name, jName: jName, sig: sig, isConstructor: isConstructor, isStatic: isStatic, isProp: isProp, isFinal: isFinal, isExported: isExported)

const ProcNamePos = 0
const ProcParamsPos = 3

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
  expectKind n[ProcNamePos], {nnkIdent, nnkPostfix}
  let i = newIdentNode($v)
  let r = getProcSignature(n[ProcParamsPos])
  result = quote do:
    let `i` = `r`

proc findPragma(n: NimNode, name: string): bool {.compileTime.} =
  for p in n.pragma:
    if (p.kind == nnkIdent or p.kind == nnkAccQuoted) and p.nodeToString == name:
      return true
    elif p.kind == nnkExprColonExpr and p[0].nodeToString == name:
      return true
  return false

proc findPragmaValue(n: NimNode, name: string): Option[string] {.compileTime.} =
  for p in n.pragma:
    if p.kind == nnkExprColonExpr and p[0].nodeToString == name:
      return p[1].nodeToString.some
  return string.none

proc parseProcDef(n: NimNode, def: NimNode): NimNode {.compileTime.} =
  result = newStmtList()
  expectKind n, nnkProcDef
  expectKind n[ProcNamePos], {nnkIdent, nnkPostfix}

  var name,
      jName,
      sig,
      isConstructor,
      isStatic,
      isProp,
      isFinal,
      isExported : NimNode

  if n[ProcNamePos].kind == nnkPostfix:
    assert $n[ProcNamePos][0].toStrLit == "*"
    name = newStrLitNode(n[ProcNamePos][1].nodeToString)
    isExported = bindSym"true"
  else:
    name = newStrLitNode($n[ProcNamePos].nodeToString)
    isExported = bindSym"false"
  expectKind n[ProcParamsPos], nnkFormalParams

  # Check constructor by name
  if $name == "new":
    jName = newStrLitNode("<init>")
    isConstructor = bindSym"true"
  else:
    isConstructor = bindSym"false"
    let jn = findPragmaValue(n, "importc")
    jName = if jn.isDefined: newStrLitNode(jn.get) else: name.copyNimNode

  sig = getProcSignature(n[ProcParamsPos])

  isStatic = if findPragma(n, "static"): bindSym"true" else: bindSym"false"
  isProp = if findPragma(n, "prop"): bindSym"true" else: bindSym"false"
  isFinal = if findPragma(n, "final"): bindSym"true" else: bindSym"false"

  result.add quote do:
    `def` = initProcDef(`name`, `jName`, `sig`, `isConstructor`,  `isStatic`, `isProp`, `isFinal`, `isExported`)

macro parseProcDefTest*(i: untyped, s: expr): stmt =
  result = parseProcDef(s[0], i)

####################################################################################################
# Class definition parser

type
  ClassDef* = object
    name*: string
    jName*: string
    parent*: string
    isExported*: bool

proc initClassDef(name, jName, parent: string, isExported: bool): ClassDef =
  ClassDef(name: name, jName: jName, parent: parent, isExported: isExported)

proc parseClassDef(c: NimNode, def: NimNode): NimNode {.compileTime.} =
  expectKind c, nnkInfix
  expectKind c[0], nnkIdent

  var jNameNode,
      nameNode,
      parentNode: NimNode
  var exported = false

  if $c[0] == "of":
    if c[1].kind == nnkInfix and $c[1][0] == "as":
      jNameNode = c[1][1]
      nameNode = c[1][2]
      parentNode = c[2]
    else:
      jNameNode = c[1]
      parentNode = c[2]
      nameNode = if jNameNode.kind == nnkDotExpr: jNameNode[1].copyNimNode else: jNameNode.copyNimNode
  else:
    exported = true
    if $c[0] == "as" and $c[2][0] == "*":
      jNameNode = c[1]
      nameNode = c[2][1]
      parentNode = c[2][2][1]
    elif $c[0] == "*":
      jNameNode = c[1]
      nameNode = if jNameNode.kind == nnkDotExpr: jNameNode[1].copyNimNode else: jNameNode.copyNimNode
      parentNode = c[2][1]

  let name = nameNode.nodeToString.newStrLitNode
  let jName = jNameNode.nodeToString.newStrLitNode
  let parent = parentNode.nodeToString.newStrLitNode
  let isExported = if exported: bindSym"true" else: bindSym"false"

  result = quote do:
    `def` = initClassDef(`name`, `jName`, `parent`, `isExported`)
  
macro parseClassDefTest*(i: untyped, s: expr): stmt =
  result = parseClassDef(s[0], i)

macro jclass*(head: expr, body: expr): stmt =
  echo "HEAD:"
  echo head.treeRepr
  # echo "BODY:"
  # for son in body:
  #   echo treeRepr(son)
  result = newStmtList()
