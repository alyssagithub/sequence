import os, sys, json
from xml.sax.saxutils import escape
Root = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "plugin", "sequence")
Out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(Root), "sequence.rbxmx")
Ref = [0]
def Item(cls, name, props, children):
    Ref[0] += 1
    p = "".join(props)
    return f'<Item class="{cls}" referent="RBX{Ref[0]}"><Properties><string name="Name">{escape(name)}</string>{p}</Properties>{"".join(children)}</Item>'
def Script(cls, name, src, children, extra=None):
    props = [f'<ProtectedString name="Source"><![CDATA[{src}]]></ProtectedString>']
    if cls == "Script":
        props.append('<token name="RunContext">0</token>')
    for k, v in (extra or {}).items():
        props.append(PropXml(k, v))
    return Item(cls, name, props, children)
def ClassFor(f):
    base = f[:-5]
    if base.endswith(".legacy") or base.endswith(".server"): return base[:-7], "Script"
    if base.endswith(".client"): return base[:-7], "LocalScript"
    return base, "ModuleScript"
def PropXml(name, value):
    if isinstance(value, bool): return f'<bool name="{name}">{str(value).lower()}</bool>'
    if isinstance(value, (int, float)): return f'<float name="{name}">{value}</float>'
    if isinstance(value, str): return f'<string name="{name}">{escape(value)}</string>'
    if isinstance(value, dict):
        kind = value.get("Type")
        if kind == "Vector3": return f'<Vector3 name="{name}"><X>{value["X"]}</X><Y>{value["Y"]}</Y><Z>{value["Z"]}</Z></Vector3>'
        if kind == "Color3": return f'<Color3 name="{name}"><R>{value["R"]}</R><G>{value["G"]}</G><B>{value["B"]}</B></Color3>'
        if kind == "Enum": return f'<token name="{name}">{value["Value"]}</token>'
    raise ValueError(f"unsupported property {name}")
def Model(node, name):
    props = [PropXml(k, v) for k, v in node.get("properties", {}).items()]
    children = [Model(c, n) for n, c in node.get("children", {}).items()]
    return Item(node["className"], name, props, children)
def Emit(disk, name):
    entries = sorted(os.listdir(disk))
    files = [e for e in entries if os.path.isfile(os.path.join(disk, e)) and e.endswith(".luau")]
    models = [e for e in entries if e.endswith(".model.json")]
    fragments = [e for e in entries if e.endswith(".fragment.xml")]
    dirs = [e for e in entries if os.path.isdir(os.path.join(disk, e))]
    inits = [f for f in files if f.startswith("init.")]
    children = []
    for f in files:
        if f in inits: continue
        n, cls = ClassFor(f)
        meta = os.path.join(disk, n + ".meta.json")
        extra = json.load(open(meta, encoding="utf-8")).get("properties") if os.path.exists(meta) else None
        children.append(Script(cls, n, open(os.path.join(disk, f), encoding="utf-8").read(), [], extra))
    for d in dirs:
        children.append(Emit(os.path.join(disk, d), d))
    for m in models:
        children.append(Model(json.load(open(os.path.join(disk, m), encoding="utf-8")), m[:-11]))
    for f in fragments:
        children.append(open(os.path.join(disk, f), encoding="utf-8").read())
    if inits:
        _, cls = ClassFor(inits[0])
        return Script(cls, name, open(os.path.join(disk, inits[0]), encoding="utf-8").read(), children)
    return Item("Folder", name, [], children)
xml = '<roblox version="4">' + Emit(Root, "sequence") + '</roblox>'
open(Out, "w", encoding="utf-8").write(xml)
print(Out, len(xml), "bytes", Ref[0], "instances")
