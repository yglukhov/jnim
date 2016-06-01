import jni_api,
       strutils,
       sequtils,
       macros,
       fp.option

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

type ParamType* = string
type ProcParam* = tuple[
  name: string,
  `type`: ParamType
]

type
  ProcDef* = object
    name*: string
    jName*: string
    isConstructor*: bool
    isStatic*: bool
    isProp*: bool
    isFinal*: bool
    isExported*: bool
    params*: seq[ProcParam]
    retType*: ParamType
    
proc initProcDef(name: string, jName: string, isConstructor, isStatic, isProp, isFinal, isExported: bool, params: seq[ProcParam] = @[], retType = "void"): ProcDef =
  ProcDef(name: name, jName: jName, isConstructor: isConstructor, isStatic: isStatic, isProp: isProp, isFinal: isFinal, isExported: isExported, params: params, retType: retType)

const ProcNamePos = 0
const ProcParamsPos = 3

####################################################################################################
# Proc signature

proc concat(s: varargs[string]): string = "(" & s.join() & ")"

proc getProcSignature(pd: ProcDef): NimNode {.compileTime.} =
  let ret = parseExpr("jniSig($#)" % pd.retType)
  if pd.isProp == true:
    return quote do:
      `ret`

  var params = newCall(bindSym("concat"))
  for p in pd.params:
    params.add(parseExpr("jniSig($#)" % p.`type`))
  
  result = quote do:
    `params` & `ret`

proc fillProcParams(pd: var ProcDef, n: NimNode) {.compileTime.} =
  expectKind n, nnkFormalParams
  let hasRet = n.len > 0 and n[0].kind == nnkIdent
  let hasParams = n.len > 1

  pd.retType = if hasRet: n[0].nodeToString else: "void"

  pd.params = newSeq[ProcParam]()
  if hasParams:
    for i in 1..<n.len:
      pd.params.add((n[i][0].nodeToString, n[i][1].nodeToString))
  
####################################################################################################
# Proc definition

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

proc parseProcDef(n: NimNode): ProcDef {.compileTime.} =
  expectKind n, nnkProcDef
  expectKind n[ProcNamePos], {nnkIdent, nnkPostfix}

  if n[ProcNamePos].kind == nnkPostfix:
    assert $n[ProcNamePos][0].toStrLit == "*"
    result.name = n[ProcNamePos][1].nodeToString
    result.isExported = true
  else:
    result.name = n[ProcNamePos].nodeToString
    result.isExported = false
  expectKind n[ProcParamsPos], nnkFormalParams

  # Check constructor by name
  if result.name == "new":
    result.jName = "<init>"
    result.isConstructor = true
  else:
    result.isConstructor = false
    let jn = findPragmaValue(n, "importc")
    result.jName = if jn.isDefined: jn.get else: result.name

  result.isStatic = findPragma(n, "static")
  result.isProp = findPragma(n, "prop")
  result.isFinal = findPragma(n, "final")

  fillProcParams(result, n[ProcParamsPos])

proc fillProcDef(n: NimNode, def: NimNode): NimNode {.compileTime.} =
  expectKind n, nnkProcDef
  expectKind n[ProcNamePos], {nnkIdent, nnkPostfix}

  var name,
      jName,
      isConstructor,
      isStatic,
      isProp,
      isFinal,
      isExported,
      params,
      retType : NimNode
  
  let pd = parseProcDef(n)

  name = pd.name.newStrLitNode
  jName = pd.jName.newStrLitNode
  isConstructor = if pd.isConstructor: bindSym"true" else: bindSym"false"
  isStatic = if pd.isStatic: bindSym"true" else: bindSym"false"
  isProp = if pd.isProp: bindSym"true" else: bindSym"false"
  isFinal = if pd.isFinal: bindSym"true" else: bindSym"false"
  isExported = if pd.isExported: bindSym"true" else: bindSym"false"
  var paramsVals = "@[" & pd.params.mapIt("(\"" & it.name & "\", \"" & it.`type` & "\")").join(",") & "]"
  params = paramsVals.parseExpr
  retType = pd.retType.newStrLitNode

  result = quote do:
    `def` = initProcDef(`name`, `jName`, `isConstructor`, `isStatic`, `isProp`, `isFinal`, `isExported`, `params`, `retType`)

macro parseProcDefTest*(i: untyped, s: expr): stmt =
  result = fillProcDef(s[0], i)

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

proc parseClassDef(c: NimNode): ClassDef {.compileTime.} =
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

  let name = nameNode.nodeToString
  let jName = jNameNode.nodeToString
  let parent = parentNode.nodeToString

  initClassDef(name, jName, parent, exported)

proc fillClassDef(c: NimNode, def: NimNode): NimNode {.compileTime.} =
  let cd = parseClassDef(c)
  
  let name = cd.name.newStrLitNode
  let jName = cd.jName.newStrLitNode
  let parent = cd.parent.newStrLitNode
  let isExported = if cd.isExported: bindSym"true" else: bindSym"false"

  result = quote do:
    `def` = initClassDef(`name`, `jName`, `parent`, `isExported`)
  
macro parseClassDefTest*(i: untyped, s: expr): stmt =
  result = fillClassDef(if s.kind == nnkStmtList: s[0] else: s, i)

####################################################################################################
# Type generator

template identEx(isExported: bool, name: string): expr =
  if isExported: postfix(ident(name), "*") else: ident(name)

proc generateClassType(def: NimNode): NimNode {.compileTime.} =
  let cd = parseClassDef(def)
  let className = ident(cd.name)
  let classNameEx = identEx(cd.isExported, cd.name)
  let parentName = ident(cd.parent)
  let jniSig = identEx(cd.isExported, "jniSig")
  let jName = cd.jName.newStrLitNode
  result = quote do:
    type `classNameEx` = ref object of `parentName`
    proc `jniSig`(t: typedesc[`className`]): string = fqcn(`jName`)

proc generateMethod(def: NimNode): NimNode {.compileTime.} =
  let pd = parseProcDef(def)
  result = newStmtList()

proc generateClassDef(head: NimNode, body: NimNode): NimNode {.compileTime.} =
  result = newStmtList()
  result.add generateClassType(head)
  if body.kind == nnkStmtList:
    for def in body:
      result.add generateMethod(def)
  else:
    result.add generateMethod(body)

macro jclass*(head: expr, body: expr): stmt {.immediate.} =
  result = generateClassDef(head, body)
  
