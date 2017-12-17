import parseutils, strutils, macros


type
    AccessType* = enum
        atPublic
        atPrivate
        atProtected

    GenericArgDef* = object
        name*: TypeName
        relation*: string
        to*: TypeName

    TypeName* = object
        name*: string
        genericArgs*: seq[GenericArgDef]
        isArray*: bool

    MethodDef* = object
        retType*: TypeName
        argTypes*: seq[TypeName]
        genericArgs*: seq[GenericArgDef]
        name*: string
        access*: AccessType
        synchronized*: bool
        prop*: bool
        throws*: seq[TypeName]
        descriptor*: string

    ClassDef* = object
        methods*: seq[MethodDef]
        name*: TypeName
        extends*: TypeName
        implements*: seq[TypeName]
        access*: AccessType
        final*: bool

proc parseAccessor(s: string, at: var AccessType, start: int): int =
    at = atPublic
    result = s.skip("public", start)
    if result == 0:
        at = atPrivate
        result = s.skip("private", start)
        if result == 0:
            at = atProtected
            result = s.skip("protected", start)

proc parseFinalFlag(s: string, final: var bool, start: int): int =
    result = s.skip("final ", start)
    final = result != 0

proc parseTypeName(s: string, tn: var TypeName, start: int): int

proc parseExtendsSection(s: string, extends: var TypeName, start: int): int =
    result = s.skip("extends ", start)
    if result != 0:
        result += s.parseTypeName(extends, result + start)

proc parseCommaSeparatedTypeList(s: string, types: var seq[TypeName], start: int): int =
    result += start
    defer: result -= start
    while true:
        types.add(TypeName())
        result += s.skipWhitespace(result)
        var pos = s.parseTypeName(types[^1], result)
        result += pos
        if pos == 0:
            types.setLen(types.len - 1)
            break
        result += s.skipWhitespace(result)
        pos = s.skip(",", result)
        result += pos
        if pos == 0:
            break

proc parseImplementsSection(s: string, implements: var seq[TypeName], start: int): int =
    result = s.skip("implements ", start)
    if result != 0:
        result += start
        defer: result -= start
        implements = newSeq[TypeName]()
        result += s.parseCommaSeparatedTypeList(implements, result)

proc parseGenericArgName(s: string, name: var TypeName, start: int): int =
    result = s.skip("?", start)
    if result != 0:
        name.name = "?"
    else:
        result = s.parseTypeName(name, start)

proc parseGenericRelation(s: string, relation: var string, start: int): int =
    for r in ["super", "extends"]:
        result = s.skip(r, start)
        if result != 0:
            relation = r
            break

proc parseGenericArgDef(s: string, def: var GenericArgDef, start: int): int =
    result = s.parseGenericArgName(def.name, start)
    result += start
    defer: result -= start
    result += s.skipWhitespace(result)
    var pos = s.parseGenericRelation(def.relation, result)
    result += pos
    if pos != 0:
        result += s.skipWhitespace(result)
        result += s.parseTypeName(def.to, result)

proc parseGenericArgs(s: string, args: var seq[GenericArgDef], start: int): int =
    result = s.skip("<", start)
    if result != 0:
        result += start
        defer: result -= start
        args = newSeq[GenericArgDef]()
        while true:
            args.add(GenericArgDef())
            result += s.skipWhitespace(result)
            var pos = s.parseGenericArgDef(args[^1], result)
            result += pos
            if pos == 0:
                pos = s.skip(">", result)
                assert(pos == 1)
                result += pos
                args.setLen(args.len - 1)
                break
            result += s.skipWhitespace(result)
            pos = s.skip(",", result)
            result += pos
            if pos == 0:
                pos = s.skip(">", result)
                assert(pos == 1)
                result += pos
                break

proc parseTypeName(s: string, tn: var TypeName, start: int): int =
    result = s.parseWhile(tn.name, IdentChars + {'.', '$'}, start)
    if result != 0:
        result += s.parseGenericArgs(tn.genericArgs, start + result)
    var pos = s.skip("[]", start + result)
    result += pos
    if pos != 0:
        tn.isArray = true

proc parseMethodModifiers(s: string, meth: var MethodDef, start: int): int =
    var pos = s.skip("synchronized", start)
    result += pos
    result += start
    defer: result -= start
    if pos != 0:
        meth.synchronized = true
        result += s.skipWhitespace(result)
    pos = s.skip("static", result)
    result += pos
    result += s.skipWhitespace(result)
    pos = s.skip("native", result)
    result += pos
    result += s.skipWhitespace(result)
    pos = s.skip("final", result)
    result += pos
    result += s.skipWhitespace(result)

proc parseMethodThrows(s: string, throws: var seq[TypeName], start: int): int =
    result += start
    defer: result -= start
    result += s.skipWhitespace(result)
    var pos = s.skip("throws", result)
    result += pos
    if pos != 0:
        throws = newSeq[TypeName]()
        result += s.parseCommaSeparatedTypeList(throws, result)

proc parseFieldDescriptor(s: string, meth: var MethodDef, start: int): int =
    var pos = s.skip("descriptor: ", start)
    if pos != 0:
        result = start + pos
        defer: result -= start
        result += s.parseUntil(meth.descriptor, '\l', result)

proc parseMethod(s: string, meth: var MethodDef, start: int): int =
    result += start
    defer: result -= start
    result += s.skipWhitespace(result)
    var pos = s.parseAccessor(meth.access, result)
    result += pos
    if pos == 0:
        return 0
    result += s.skipWhitespace(result)
    result += s.parseMethodModifiers(meth, result)
    result += s.parseTypeName(meth.retType, result)
    pos = s.skip("(", result)
    result += pos
    if pos != 0:
        # This is constructor
        meth.name = meth.retType.name
        meth.genericArgs = meth.retType.genericArgs
        meth.retType.name = "void"
        meth.retType.genericArgs = nil
    else:
        var dummyTypeName : TypeName
        result += s.skipWhitespace(result)
        result += s.parseTypeName(dummyTypeName, result)
        meth.name = dummyTypeName.name
        meth.genericArgs = dummyTypeName.genericArgs
        result += s.skipWhitespace(result)
        pos = s.skip("(", result)
        result += pos
        if pos == 0:
            if s.skip(";", result) == 1:
                meth.prop = true
    if not meth.prop:
        meth.argTypes = newSeq[TypeName]()
        result += s.parseCommaSeparatedTypeList(meth.argTypes, result)
        result += s.skipWhitespace(result)
        pos = s.skip(")", result)
        result += pos
        assert(pos != 0)
        result += s.parseMethodThrows(meth.throws, result)
    pos = s.skip(";", result)
    result += pos
    assert(pos != 0)
    result += s.skipWhitespace(result)
    result += s.parseFieldDescriptor(meth, result)

proc parseMethods(s: string, methods: var seq[MethodDef], start: int): int =
    result += start
    defer: result -= start
    while true:
        methods.add(MethodDef())
        var pos = s.parseMethod(methods[^1], result)
        result += pos
        if pos == 0:
            methods.setLen(methods.len - 1)
            break

proc parseJavap*(s: string, def: var ClassDef): int =
    def.implements = newSeq[TypeName]()
    def.methods = newSeq[MethodDef]()

    var pos = s.skipUntil('\l') + 1
    pos += s.parseAccessor(def.access, pos)
    pos += s.skipWhitespace(pos)
    pos += s.parseFinalFlag(def.final, pos)
    pos += s.skip("class", pos)
    pos += s.skipWhitespace(pos)
    pos += s.parseTypeName(def.name, pos)
    pos += s.skipWhitespace(pos)
    pos += s.parseExtendsSection(def.extends, pos)
    pos += s.skipWhitespace(pos)
    pos += s.parseImplementsSection(def.implements, pos)
    pos += s.skipWhitespace(pos)
    pos += s.skip("{", pos)
    pos += s.parseMethods(def.methods, pos)

proc nodeToString(e: NimNode): string {.compileTime.} =
    if e.kind == nnkIdent:
        result = $e
    elif e.kind == nnkAccQuoted:
        result = ""
        for s in e.children:
            result &= nodeToString(s)
    elif e.kind == nnkDotExpr:
        result = nodeToString(e[0]) & "." & nodeToString(e[1])
    else:
        echo treeRepr(e)
        assert(false, "Cannot stringize node")

macro jnimport_all*(e: expr): stmt =
    let className = nodeToString(e)
    let javapOutput = staticExec("javap -public -s " & className)
    var cd: ClassDef
    discard parseJavap(javapOutput, cd)

    echo cd
