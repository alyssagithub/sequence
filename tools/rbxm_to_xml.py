import struct, sys, base64
import lz4.block, zstandard
from xml.sax.saxutils import escape

Enums = {"Material": 1, "SurfaceType": 1, "PartType": 1, "FormFactor": 1, "NormalId": 1, "RigType": 1, "HumanoidRigType": 1, "MeshType": 1, "Style": 1, "DisplayDistanceType": 1, "NameOcclusion": 1, "HealthDisplayType": 1, "CollisionFidelity": 1, "RenderFidelity": 1, "HumanoidStateType": 1}
Skip = {"Attributes", "Tags", "AttributesSerialize", "Capabilities", "DefinesCapabilities", "SourceAssetId", "HistoryId", "ModelMeshData", "ModelMeshSize", "ModelMeshCFrame", "PhysicsData", "PhysicalConfigData", "MaterialVariantSerialized", "UniqueId", "WorldPivotData", "ModelStreamingMode", "NeedsPivotMigration", "StreamingMode", "LevelOfDetail", "Scale", "ScaleFactor", "PrimaryPart", "CollisionGroupId", "CollisionGroup"}

def Chunks(data):
    pos = 32
    while pos < len(data):
        name = data[pos:pos + 4]
        comp, uncomp, _ = struct.unpack("<III", data[pos + 4:pos + 16])
        pos += 16
        payload = data[pos:pos + (comp if comp else uncomp)]
        pos += comp if comp else uncomp
        if comp:
            payload = zstandard.ZstdDecompressor().decompress(payload, max_output_size=uncomp) if payload[:4] == b"\x28\xb5\x2f\xfd" else lz4.block.decompress(payload, uncompressed_size=uncomp)
        yield name, payload
        if name == b"END\x00":
            return

def Untransform(v):
    return (v >> 1) ^ -(v & 1)

def ReadInts(buf, count):
    raw = struct.unpack(">%dI" % count, buf[:4 * count])
    return [Untransform(struct.unpack("<i", struct.pack("<I", v))[0]) for v in raw], buf[4 * count:]

def ReadFloats(buf, count):
    out = []
    for i in range(count):
        v = struct.unpack(">I", buf[4 * i:4 * i + 4])[0]
        v = ((v >> 1) | ((v & 1) << 31)) & 0xFFFFFFFF
        out.append(struct.unpack("<f", struct.pack("<I", v))[0])
    return out, buf[4 * count:]

def Interleave(buf, count, width):
    cols = [buf[i * count:(i + 1) * count] for i in range(width)]
    return b"".join(bytes(cols[c][r] for c in range(width)) for r in range(count)), buf[width * count:]

def ReadF32(buf, count):
    inter, rest = Interleave(buf, count, 4)
    return ReadFloats(inter, count)[0], rest

def ReadI32(buf, count):
    inter, rest = Interleave(buf, count, 4)
    return ReadInts(inter, count)[0], rest

def ReadStrings(buf, count):
    out = []
    for _ in range(count):
        n, = struct.unpack("<I", buf[:4]); buf = buf[4:]
        out.append(buf[:n]); buf = buf[n:]
    return out

Axes = [(1, 0, 0), (0, 1, 0), (0, 0, 1), (-1, 0, 0), (0, -1, 0), (0, 0, -1)]

def Rotation(idx):
    a = Axes[idx // 6]
    b = Axes[idx % 6]
    c = (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
    return [a[0], b[0], c[0], a[1], b[1], c[1], a[2], b[2], c[2]]

def Convert(path, out, root_name=None):
    data = open(path, "rb").read()
    classes = {}
    props = {}
    parents = {}
    order = []
    for name, p in Chunks(data):
        if name == b"INST":
            cid, = struct.unpack("<I", p[:4]); n, = struct.unpack("<I", p[4:8]); cname = p[8:8 + n].decode(); rest = p[8 + n:]
            has_service = rest[0]; count, = struct.unpack("<I", rest[1:5]); rest = rest[5:]
            ids, _ = ReadI32(rest, count)
            acc = 0; refs = []
            for d in ids:
                acc += d; refs.append(acc)
            classes[cid] = (cname, refs)
            for r in refs:
                props.setdefault(r, {})
                order.append(r)
        elif name == b"PROP":
            cid, = struct.unpack("<I", p[:4]); n, = struct.unpack("<I", p[4:8]); pname = p[8:8 + n].decode(); t = p[8 + n]; body = p[9 + n:]
            cname, refs = classes[cid]
            count = len(refs)
            vals = None
            if t == 1:
                vals = [("string", v.decode("utf-8", "replace")) for v in ReadStrings(body, count)]
            elif t == 2:
                vals = [("bool", "true" if body[i] else "false") for i in range(count)]
            elif t == 3:
                vals = [("int", str(v)) for v in ReadI32(body, count)[0]]
            elif t == 4:
                vals = [("float", repr(v)) for v in ReadF32(body, count)[0]]
            elif t == 5:
                vals = [("double", repr(v)) for v in struct.unpack("<%dd" % count, body[:8 * count])]
            elif t == 9:
                vals = [("UDim2", (0, 0, 0, 0))] * count
                sx, r = ReadF32(body, count); ox, r = ReadI32(r, count); sy, r = ReadF32(r, count); oy, r = ReadI32(r, count)
                vals = [("UDim2", (sx[i], ox[i], sy[i], oy[i])) for i in range(count)]
            elif t == 12:
                r, g, b = [ReadF32(body[4 * count * i:], count)[0] for i in range(3)]
                vals = [("Color3", (r[i], g[i], b[i])) for i in range(count)]
            elif t == 13:
                x, r = ReadF32(body, count); y, r = ReadF32(r, count)
                vals = [("Vector2", (x[i], y[i])) for i in range(count)]
            elif t == 14:
                x, r = ReadF32(body, count); y, r = ReadF32(r, count); z, r = ReadF32(r, count)
                vals = [("Vector3", (x[i], y[i], z[i])) for i in range(count)]
            elif t == 16:
                rots = []
                r = body
                for i in range(count):
                    idx = r[0]; r = r[1:]
                    if idx == 0:
                        m = list(struct.unpack("<9f", r[:36])); r = r[36:]
                    else:
                        m = Rotation(idx)
                    rots.append(m)
                x, r = ReadF32(r, count); y, r = ReadF32(r, count); z, r = ReadF32(r, count)
                vals = [("CFrame", (x[i], y[i], z[i], rots[i])) for i in range(count)]
            elif t == 18:
                inter, _ = Interleave(body, count, 4)
                vals = [("token", str(struct.unpack(">I", inter[4 * i:4 * i + 4])[0])) for i in range(count)]
            elif t == 19:
                ids, _ = ReadI32(body, count)
                acc = 0; out_refs = []
                for d in ids:
                    acc += d; out_refs.append(acc)
                vals = [("Ref", v) for v in out_refs]
            elif t == 26:
                vals = [("Color3uint8", (body[i], body[count + i], body[2 * count + i])) for i in range(count)]
            elif t == 27:
                vals = [("int64", str(v)) for v in struct.unpack("<%dq" % count, body[:8 * count])]
            if vals is None:
                continue
            for i, r in enumerate(refs):
                props[r][pname] = vals[i]
        elif name == b"PRNT":
            count, = struct.unpack("<I", p[1:5]); r = p[5:]
            kids, r = ReadI32(r, count); pars, _ = ReadI32(r, count)
            ka = 0; pa = 0
            for i in range(count):
                ka += kids[i]; pa += pars[i]
                parents[ka] = pa
    children = {}
    for r in order:
        children.setdefault(parents.get(r, -1), []).append(r)
    def Class(r):
        for cid, (cname, refs) in classes.items():
            if r in refs:
                return cname
    def Prop(name, val):
        kind, v = val
        if kind == "string":
            tag = "ProtectedString" if name == "Source" else "string"
            return f'<{tag} name="{name}">{escape(v)}</{tag}>'
        if kind in ("bool", "int", "float", "double", "token", "int64"):
            return f'<{kind} name="{name}">{v}</{kind}>'
        if kind == "Color3":
            return f'<Color3 name="{name}"><R>{v[0]!r}</R><G>{v[1]!r}</G><B>{v[2]!r}</B></Color3>'
        if kind == "Color3uint8":
            return f'<Color3uint8 name="{name}">{(0xFF << 24) | (v[0] << 16) | (v[1] << 8) | v[2]}</Color3uint8>'
        if kind == "Vector3":
            return f'<Vector3 name="{name}"><X>{v[0]!r}</X><Y>{v[1]!r}</Y><Z>{v[2]!r}</Z></Vector3>'
        if kind == "Vector2":
            return f'<Vector2 name="{name}"><X>{v[0]!r}</X><Y>{v[1]!r}</Y></Vector2>'
        if kind == "UDim2":
            return f'<UDim2 name="{name}"><XS>{v[0]!r}</XS><XO>{v[1]}</XO><YS>{v[2]!r}</YS><YO>{v[3]}</YO></UDim2>'
        if kind == "CFrame":
            x, y, z, m = v
            names = ["R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
            return f'<CoordinateFrame name="{name}"><X>{x!r}</X><Y>{y!r}</Y><Z>{z!r}</Z>' + "".join(f"<{n}>{m[i]!r}</{n}>" for i, n in enumerate(names)) + "</CoordinateFrame>"
        if kind == "Ref":
            return f'<Ref name="{name}">{"null" if v < 0 else f"X{v}"}</Ref>'
        return ""
    def Emit(r):
        cname = Class(r)
        ps = props[r]
        body = "".join(Prop(k, v) for k, v in ps.items() if k not in Skip)
        return f'<Item class="{cname}" referent="X{r}"><Properties>{body}</Properties>' + "".join(Emit(c) for c in children.get(r, [])) + "</Item>"
    roots = children.get(-1, [])
    xml = "".join(Emit(r) for r in roots)
    if root_name:
        xml = xml.replace(f'<string name="Name">{escape(Class(roots[0]) and props[roots[0]]["Name"][1])}</string>', f'<string name="Name">{root_name}</string>', 1)
    open(out, "w", encoding="utf-8").write(xml)
    print(out, len(xml), "bytes", len(order), "instances")

if __name__ == "__main__":
    Convert(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)