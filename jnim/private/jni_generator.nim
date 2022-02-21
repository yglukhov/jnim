import jni_api, strutils, sequtils, macros

from typetraits import name

####################################################################################################
# Module parameters
const CONSTRUCTOR_NAME = "new"

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
  elif n.kind == nnkBracketExpr:
    let children = toSeq(n.children)
    let params = children[1..^1].map(nodeToString).join(",")
    result = "$#[$#]" % [n[0].nodeToString, params]
  else:
    assert false, "Can't stringify " & $n.kind

####################################################################################################
# Types declarations

type ParamType* = string
type ProcParam* = tuple[
  name: string,
  `type`: ParamType
]
type GenericType* = string

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
    genericTypes*: seq[GenericType]

proc initProcDef(name: string, jName: string, isConstructor, isStatic, isProp, isFinal, isExported: bool, params: seq[ProcParam] = @[], retType = "void", genericTypes: seq[GenericType] = @[]): ProcDef =
  ProcDef(name: name, jName: jName, isConstructor: isConstructor, isStatic: isStatic, isProp: isProp, isFinal: isFinal, isExported: isExported, params: params, retType: retType, genericTypes: genericTypes)

type
  ClassDef* = object
    name*: string
    jName*: string
    parent*: string
    isExported*: bool
    genericTypes*: seq[GenericType]
    parentGenericTypes*: seq[GenericType]

proc initClassDef(name, jName, parent: string, isExported: bool, genericTypes: seq[GenericType] = @[], parentGenericTypes: seq[GenericType] = @[]): ClassDef =
  ClassDef(name: name, jName: jName, parent: parent, isExported: isExported, genericTypes: genericTypes, parentGenericTypes: parentGenericTypes)

####################################################################################################
# Proc signature parser

const ProcNamePos = 0
const ProcParamsPos = 3

proc findNameAndGenerics(n: NimNode): (NimNode, NimNode) =
  if n.kind == nnkBracketExpr:
    result[0] = n[0]
    result[1] = n
  elif n.kind == nnkInfix and n[2].kind == nnkBracket:
    result[0] = n[1]
    result[1] = n[2]
  else:
    result[0] = n
    result[1] = nil

proc parseGenericsNode(n: NimNode): seq[GenericType] =
  if n.isNil: return

  expectKind n, {nnkBracketExpr, nnkBracket}
  result = newSeq[GenericType]()
  for i in (ord(n.kind)-ord(nnkBracket))..<n.len:
    expectKind n[i], nnkIdent
    result.add($n[i])

proc parseProcGenericsNode(n: NimNode): seq[GenericType] =
  expectKind n, nnkProcDef
  result = newSeq[GenericType]()
  if n[2].kind == nnkGenericParams:
    let idents = n[2][0]
    for i in 0..<(idents.len-1):
      if idents[i].kind == nnkIdent:
        result.add($idents[i])

####################################################################################################
# Proc signature

proc concatParams(s: varargs[string]): string = "(" & s.join() & ")"

proc collectGenericParameters(cd: ClassDef, pd: ProcDef): seq[GenericType] =
  result = newSeq[GenericType]()
  for t in cd.genericTypes:
    result.add t
  for t in pd.genericTypes:
    if not(t in result): result.add t

proc isGenericType(cd: ClassDef, pd: ProcDef, `type`: ParamType): bool =
  `type` in collectGenericParameters(cd, pd)

proc genJniSig(cd: ClassDef, pd: ProcDef, `type`: ParamType): NimNode {.compileTime.} =
  if isGenericType(cd, pd, `type`):
    parseExpr("jniSig(jobject)")
  else:
    parseExpr("jniSig($#)" % `type`)

proc getProcSignature(cd: ClassDef, pd: ProcDef): NimNode {.compileTime.} =
  let ret = genJniSig(cd, pd, pd.retType)
  if pd.isProp == true:
    return quote do:
      `ret`

  var params = newCall(bindSym("concatParams"))
  for p in pd.params:
    params.add(genJniSig(cd, pd, p.`type`))

  result = quote do:
    `params` & `ret`

proc fillProcParams(pd: var ProcDef, n: NimNode) {.compileTime.} =
  expectKind n, nnkFormalParams
  let hasRet = n.len > 0 and n[0].kind != nnkEmpty
  let hasParams = n.len > 1

  pd.retType = if hasRet: n[0].nodeToString else: "void"

  pd.params = newSeq[ProcParam]()
  if hasParams:
    for i in 1..<n.len:
      # Process ``x, y: jint`` like parameters definitions
      let maxI = n[i].len-3
      for v in 0..maxI:
        pd.params.add((n[i][v].nodeToString, n[i][maxI+1].nodeToString))

####################################################################################################
# Proc definition

proc findPragma(n: NimNode, name: string): bool {.compileTime.} =
  for p in n.pragma:
    if (p.kind == nnkIdent or p.kind == nnkAccQuoted) and p.nodeToString == name:
      return true
    elif p.kind == nnkExprColonExpr and p[0].nodeToString == name:
      return true
  return false

proc findPragmaValue(n: NimNode, name: string): string {.compileTime.} =
  for p in n.pragma:
    if p.kind == nnkExprColonExpr and p[0].nodeToString == name:
      return p[1].nodeToString

proc parseProcDef(n: NimNode): ProcDef {.compileTime.} =
  expectKind n, nnkProcDef
  expectKind n[ProcNamePos], {nnkIdent, nnkPostfix, nnkAccQuoted}


  if n[ProcNamePos].kind == nnkPostfix:
    assert $n[ProcNamePos][0].toStrLit == "*"
    result.name = n[ProcNamePos][1].nodeToString
    result.isExported = true
  else:
    result.name = n[ProcNamePos].nodeToString
    result.isExported = false
  expectKind n[ProcParamsPos], nnkFormalParams

  # Check constructor by name
  if result.name == CONSTRUCTOR_NAME:
    result.jName = "<init>"
    result.isConstructor = true
  else:
    result.isConstructor = false
    let jn = findPragmaValue(n, "importc")
    result.jName = if jn.len == 0: result.name else: jn

  result.isStatic = findPragma(n, "static")
  result.isProp = findPragma(n, "prop")
  result.isFinal = findPragma(n, "final")
  result.genericTypes = parseProcGenericsNode(n)

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

  result = newStmtList quote do:
    `def` = initProcDef(`name`, `jName`, `isConstructor`, `isStatic`, `isProp`, `isFinal`, `isExported`, `params`, `retType`)

  for g in pd.genericTypes:
    let v = g.newStrLitNode
    let q = quote do:
      `def`.genericTypes.add(`v`)
    result.add(q)

macro parseProcDefTest*(i: untyped, s: untyped): untyped =
  result = fillProcDef(s[0], i)

####################################################################################################
# Class definition parser

proc parseClassDef(c: NimNode): ClassDef {.compileTime.} =
  expectKind c, nnkInfix
  expectKind c[0], nnkIdent

  var jNameNode,
      nameNode,
      parentNode,
      generics,
      parentGenerics: NimNode
  var exported = false

  proc hasExportMarker(n: NimNode): bool = n.findChild(it.kind == nnkIdent and $it == "*") != nil

  proc nameFromJName(jNameNode: NimNode): NimNode =
    result = if jNameNode.kind == nnkDotExpr:
               jNameNode[1].copyNimTree
             elif jNameNode.kind == nnkInfix and jNameNode[0].nodeToString == "$":
               jNameNode[2].copyNimTree
             else:
               jNameNode.copyNimTree

  if $c[0] == "of":
    if c[1].kind == nnkInfix:
      if $c[1][0] == "as":
        exported = c[1][1].hasExportMarker
        (jNameNode, generics) = c[1][1].findNameAndGenerics
        nameNode = c[1][2]
        (parentNode, parentGenerics) = c[2].findNameAndGenerics
      elif $c[1][0] == "*":
        exported = true
        (jNameNode, generics) = c[1].findNameAndGenerics
        nameNode = nameFromJName(jNameNode)
        (parentNode, parentGenerics) = c[2].findNameAndGenerics
      else:
        (jNameNode, generics) = c[1].findNameAndGenerics
        (parentNode, parentGenerics) = c[2].findNameAndGenerics
        nameNode = nameFromJName(jNameNode)
    else:
      (jNameNode, generics) = c[1].findNameAndGenerics
      (parentNode, parentGenerics) = c[2].findNameAndGenerics
      nameNode = nameFromJName(jNameNode)
  else:
    exported = true
    if $c[0] == "as" and $c[2][0] == "*":
      (jNameNode, generics) = c[1].findNameAndGenerics
      nameNode = c[2][1]
      (parentNode, parentGenerics) = c[2][2][1].findNameAndGenerics
    elif $c[0] == "*":
      (jNameNode, generics) = c[1].findNameAndGenerics
      nameNode = nameFromJName(jNameNode)
      (parentNode, parentGenerics) = c[2][1].findNameAndGenerics

  let name = nameNode.nodeToString
  let jName = jNameNode.nodeToString
  let parent = parentNode.nodeToString

  initClassDef(name, jName, parent, exported, parseGenericsNode(generics), parseGenericsNode(parentGenerics))

proc fillClassDef(c: NimNode, def: NimNode): NimNode {.compileTime.} =
  let cd = parseClassDef(c)

  let name = cd.name.newStrLitNode
  let jName = cd.jName.newStrLitNode
  let parent = cd.parent.newStrLitNode
  let isExported = if cd.isExported: bindSym"true" else: bindSym"false"

  result = newStmtList quote do:
    `def` = initClassDef(`name`, `jName`, `parent`, `isExported`)

  for g in cd.genericTypes:
    let v = g.newStrLitNode
    let q = quote do:
      `def`.genericTypes.add(`v`)
    result.add(q)

  for g in cd.parentGenericTypes:
    let v = g.newStrLitNode
    let q = quote do:
      `def`.parentGenericTypes.add(`v`)
    result.add(q)

macro parseClassDefTest*(i: untyped, s: untyped): untyped =
  result = fillClassDef(if s.kind == nnkStmtList: s[0] else: s, i)

####################################################################################################
# Type generator

template identEx(isExported: bool, name: string, isSetter = false, isQuoted = false): untyped =
  let id =
    if isSetter:
      newNimNode(nnkAccQuoted).add(ident(name), ident("="))
    else:
      if isQuoted: newNimNode(nnkAccQuoted).add(ident(name)) else: ident(name)
  if isExported: postfix(id, "*") else: id

proc mkGenericParams(p: seq[GenericType]): NimNode {.compileTime.} =
  if p.len == 0:
    result = newEmptyNode()
  else:
    result = newNimNode(nnkGenericParams).add(newNimNode(nnkIdentDefs))
    for name in p:
      result[0].add(ident(name))
    # Add type and default value for the idenifiers list
    result[0].add(newEmptyNode()).add(newEmptyNode())

proc mkTypeHelper(name: string, params: seq[GenericType]): NimNode {.compileTime.} =
  if params.len == 0:
    result = ident(name)
  else:
    result = newNimNode(nnkBracketExpr).add(ident(name))
    for n in params:
      result.add(ident(n))

proc mkType(cd: ClassDef): NimNode {.compileTime.} =
  result = mkTypeHelper(cd.name, cd.genericTypes)

proc mkNonVirtualType(cd: ClassDef): NimNode {.compileTime.} =
  result = mkTypeHelper("JnimNonVirtual_" & cd.name, cd.genericTypes)

proc mkParentType(cd: ClassDef): NimNode {.compileTime.} =
  result = mkTypeHelper(cd.parent, cd.parentGenericTypes)

proc mkNonVirtualParentType(cd: ClassDef): NimNode {.compileTime.} =
  result = mkTypeHelper("JnimNonVirtual_" & cd.parent, cd.parentGenericTypes)

proc mkTypedesc(cd: ClassDef): NimNode {.compileTime.} =
  result = newNimNode(nnkBracketExpr).add(ident"typedesc").add(cd.mkType)

template toConstCString(e: string): cstring = static(cstring(e))

proc generateClassDef(cd: ClassDef): NimNode {.compileTime.} =
  let className = ident(cd.name)
  let classNameEx = identEx(cd.isExported, cd.name)
  let nonVirtualClassNameEx = identEx(cd.isExported, "JnimNonVirtual_" & cd.name)
  let parentType = cd.mkParentType
  let nonVirtualParentType = cd.mkNonVirtualParentType
  let jniSigIdent = identEx(cd.isExported, "jniSig")
  let jniFqcnIdent = identEx(cd.isExported, "jniFqcn")
  let jName = cd.jName.newStrLitNode
  let getClassId = identEx(cd.isExported, "getJVMClassForType")
  let eqOpIdent = identEx(cd.isExported, "==", isQuoted = true)
  let seqEqOpIdent = identEx(cd.isExported, "==", isQuoted = true)
  result = quote do:
    type
      `classNameEx` = ref object of `parentType`
      `nonVirtualClassNameEx` {.used.} = object of `nonVirtualParentType`
    proc `jniFqcnIdent`(t: typedesc[`className`]): string {.used, inline.} = `jName`
    proc `jniSigIdent`(t: typedesc[`className`]): string {.used, inline.} = sigForClass(`jName`)
    proc `jniSigIdent`(t: typedesc[openarray[`className`]]): string {.used, inline.} = "[" & sigForClass(`jName`)
    proc `getClassId`(t: typedesc[`className`]): JVMClass {.used, inline.} =
      JVMClass.getByFqcn(toConstCString(fqcn(`jName`)))
    proc toJVMObject(v: `className`): JVMObject {.used, inline.} =
      v.JVMObject
    proc `eqOpIdent`(v1, v2: `className`): bool {.used, inline.} =
      return (v1.equalsRaw(v2) != JVM_FALSE)
    proc `seqEqOpIdent`(v1, v2: seq[`className`]): bool {.used.} =
      if v1.len != v2.len:
        return false
      else:
        for i in 0..<v1.len:
          if v1[i] != v2[i]:
            return false
        return true
  result[0][0][1] = mkGenericParams(cd.genericTypes)
  result[0][1][1] = mkGenericParams(cd.genericTypes)

proc generateArgs(pd: ProcDef, argsIdent: NimNode): NimNode =
  if pd.params.len > 0:
    let args = newNimNode(nnkBracket)
    for p in pd.params:
      let pi = ident(p.name)
      let q = quote do:
        when compiles(toJVMObject(`pi`)):
          `pi`.toJVMObject.toJValue
        else:
          `pi`.toJValue
      args.add(q)
    result = quote do:
      let `argsIdent` = `args`
  else:
    result = quote do:
      template `argsIdent` : untyped = []

proc fillGenericParameters(cd: ClassDef, pd: ProcDef, n: NimNode) {.compileTime.} =
  # Combines generic parameters from `pd`, `cd` and puts t into proc definition `n`
  n[2] = mkGenericParams(collectGenericParameters(cd, pd))

template withGCDisabled(body: untyped) =
  # Disabling GC is a must on Android (and maybe other platforms) in release
  # mode. Otherwise Nim GC may kick in and finalize the JVMObject we're passing
  # to JNI call before the actual JNI call is made. That is likely caused
  # by release optimizations that prevent Nim GC from "seeing" the JVMObjects
  # on the stack after their last usage, even though from the code POV they
  # are still here. This template should be used wherever jni references are
  # taken from temporary Nim objects.

  when defined(gcDestructors):
    body
  else:
    GC_disable()
    body
    GC_enable()

proc generateConstructor(cd: ClassDef, pd: ProcDef, def: NimNode): NimNode =
  assert pd.isConstructor

  let sig = getProcSignature(cd, pd)
  let cname = cd.jName.newStrLitNode
  let ctype = cd.name.ident
  let ctypeWithParams = cd.mkType

  result = def.copyNimTree
  fillGenericParameters(cd, pd, result)
  # Change return type
  result.params[0] = ctypeWithParams
  # Add first parameter
  result.params.insert(1, newIdentDefs(ident"theClassType", cd.mkTypedesc))
  let ai = ident"args"
  let args = generateArgs(pd, ai)
  result.body = quote do:
    checkInit
    withGCDisabled:
      let clazz = JVMClass.getByName(`cname`)
      `args`
    fromJObjectConsumingLocalRef(`ctypeWithParams`, newObjectRaw(clazz, toConstCString(`sig`), `ai`))

proc generateMethod(cd: ClassDef, pd: ProcDef, def: NimNode): NimNode =
  assert(not (pd.isConstructor or pd.isProp))

  let sig = getProcSignature(cd, pd)
  let pname = pd.jName.newStrLitNode
  let ctype = cd.name.ident
  result = def.copyNimTree
  fillGenericParameters(cd, pd, result)
  result.pragma = newEmptyNode()

  var objToCall: NimNode
  var objToCallIdent: NimNode
  var mIdIdent = ident"mId"

  # Add first parameter
  if pd.isStatic:
    result.params.insert(1, newIdentDefs(ident"theClassType", cd.mkTypedesc))
    objToCallIdent = ident"clazz"
    objToCall = quote do:
      let `objToCallIdent` = `ctype`.getJVMClassForType
      let `mIdIdent` = `objToCallIdent`.getStaticMethodId(`pname`, toConstCString(`sig`))

  else:
    objToCallIdent = ident"this"
    result.params.insert(1, newIdentDefs(objToCallIdent, cd.mkType))
    objToCall = quote do:
      let `mIdIdent` = `objToCallIdent`.getMethodId(`pname`, toConstCString(`sig`))

  let retType = parseExpr(pd.retType)
  let ai = ident"args"
  let args = generateArgs(pd, ai)
  result.body = quote do:
    withGCDisabled:
      `objToCall`
      `args`
    callMethod(`retType`, `objToCallIdent`, `mIdIdent`, `ai`)

proc getSuperclass(o: jobject): JVMClass =
  let clazz = theEnv.GetObjectClass(theEnv, o)
  let sclazz = theEnv.GetSuperclass(theEnv, clazz)
  result = newJVMClass(sclazz)
  theEnv.deleteLocalRef(clazz)
  theEnv.deleteLocalRef(sclazz)

proc generateNonVirtualMethod(cd: ClassDef, pd: ProcDef, def: NimNode): NimNode =
  assert(not (pd.isConstructor or pd.isProp))

  let sig = getProcSignature(cd, pd)
  let pname = pd.jName.newStrLitNode
  let ctype = cd.name.ident
  result = def.copyNimTree
  fillGenericParameters(cd, pd, result)
  result.pragma = newEmptyNode()
  result.addPragma(ident"used")

  let mIdIdent = ident"mId"
  let mClassIdent = ident"clazz"

  # Add first parameter
  let thisIdent = ident"this"
  result.params.insert(1, newIdentDefs(thisIdent, cd.mkNonVirtualType))
  let objToCall = quote do:
    let `mClassIdent` = getSuperclass(`thisIdent`.obj)
    let `mIdIdent` = `mClassIdent`.getMethodId(`pname`, toConstCString(`sig`))

  let retType = parseExpr(pd.retType)
  let ai = ident"args"
  let args = generateArgs(pd, ai)
  result.body = quote do:
    withGCDisabled:
      `objToCall`
      `args`
    callNonVirtualMethod(`retType`, `thisIdent`, `mClassIdent`, `mIdIdent`, `ai`)

proc generateProperty(cd: ClassDef, pd: ProcDef, def: NimNode, isSetter: bool): NimNode =
  assert pd.isProp

  let sig = getProcSignature(cd, pd)
  let cname = cd.jName.newStrLitNode
  let pname = pd.jName.newStrLitNode
  let ctype = cd.name.ident
  result = def.copyNimTree
  fillGenericParameters(cd, pd, result)
  result.pragma = newEmptyNode()
  result[ProcNamePos] = identEx(pd.isExported, pd.name, isSetter)
  var objToCall: NimNode
  # Add first parameter
  if pd.isStatic:
    result.params.insert(1, newIdentDefs(ident"theClassType", cd.mkTypedesc))
    objToCall = quote do:
      `ctype`.getJVMClassForType
  else:
    result.params.insert(1, newIdentDefs(ident"this", cd.mkType))
    objToCall = ident"this"
  if isSetter:
    result.params.insert(2, newIdentDefs(ident"value", result.params[0]))
    result.params[0] = newEmptyNode()
  let valType = parseExpr(pd.retType)
  var mId: NimNode
  if pd.isStatic:
    mId = quote do:
      `objToCall`.getStaticFieldId(`pname`, `sig`)
  else:
    mId = quote do:
      `objToCall`.getFieldId(`pname`, `sig`)

  if isSetter:
    result.body = quote do:
      withGCDisabled:
        setPropValue(`valType`, `objToCall`, `mId`, value)
  else:
    result.body = quote do:
      getPropValue(`valType`, `objToCall`, `mId`)

proc generateProc(cd: ClassDef, def: NimNode): NimNode {.compileTime.} =
  let pd = parseProcDef(def)
  if pd.isConstructor:
    result = generateConstructor(cd, pd, def)
  elif pd.isProp:
    result = newStmtList()
    result.add(generateProperty(cd, pd, def, false))
    if not pd.isFinal:
      result.add(generateProperty(cd, pd, def, true))
  else:
    result = newStmtList()
    result.add(generateMethod(cd, pd, def))
    if not pd.isStatic:
      result.add(generateNonVirtualMethod(cd, pd, def))

proc generateClassImpl(cd: ClassDef, body: NimNode): NimNode {.compileTime.} =
  result = newStmtList()
  if body.kind == nnkStmtList:
    for def in body:
      result.add generateProc(cd, def)
  else: result.add generateProc(cd, body)

macro jclass*(head: untyped, body: untyped): untyped =
  result = newStmtList()
  let cd = parseClassDef(head)
  result.add generateClassDef(cd)
  result.add generateClassImpl(cd, body)

macro jclassDef*(head: untyped): untyped =
  result = newStmtList()
  let cd = parseClassDef(head)
  result.add generateClassDef(cd)

macro jclassImpl*(head: untyped, body: untyped): untyped =
  result = newStmtList()
  let cd = parseClassDef(head)
  result.add generateClassImpl(cd, body)


####################################################################################################
# Operators

proc instanceOf*[T: JVMObject](obj: JVMObject, t: typedesc[T]): bool =
  ## Returns true if java object `obj` is an instance of class, represented
  ## by `T`. Behaves the same as `instanceof` operator in Java.
  ## **WARNING**: since generic parameters are not represented on JVM level,
  ## they are ignored (even though they are required by Nim syntax). This
  ## means that the following returns true:
  ## .. code-block:: nim
  ##   let a = ArrayList[Integer].new()
  ##   # true!
  ##   a.instanceOf[List[String]]

  instanceOfRaw(obj, T.getJVMClassForType)

proc jcast*[T: JVMObject](obj: JVMObject): T =
  ## Downcast operator for Java objects.
  ## Behaves like Java code `(T) obj`. That is:
  ## - If java object, referenced by `obj`, is an instance of class,
  ## represented by `T` - returns an object of `T` that references
  ## the same java object.
  ## - Otherwise raises an exception (`ObjectConversionDefect`).
  ## **WARNING**: since generic parameters are not represented on JVM level,
  ## they are ignored (even though they are required by Nim syntax). This
  ## means that the following won't raise an error:
  ## .. code-block:: nim
  ##   let a = ArrayList[Integer].new()
  ##   # no error here!
  ##   let b = jcast[List[String]](a)
  ## **WARNING**: To simplify reference handling, this implementation directly
  ## casts JVMObject to a subtype. This works, since all mapped classes have
  ## the same structure, but also breaks Nim's runtime type determination
  ## (such as `of` keyword and methods). However, native runtime type
  ## determination should not be used with mapped classes anyway.

  if not obj.instanceOf(T):
    raise newException(
      ObjectConversionDefect,
      "Failed to convert " & typetraits.name(obj.type) &
        " to " & typetraits.name(T)
    )
  # Since it is just a ref
  cast[T](obj)
