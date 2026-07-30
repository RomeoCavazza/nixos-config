#!/usr/bin/env python3
import sys
import json
from collections import deque

def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        return
        
    if isinstance(data, list):
        nodes = { item.get("path", k): item for k, item in enumerate(data) }
    elif isinstance(data, dict):
        nodes = data
    else:
        return

    for path, info in nodes.items():
        if "references" not in info:
            info["references"] = []
        if "narSize" not in info:
            info["narSize"] = 0

    indegree = { path: 0 for path in nodes }
    for path, item in nodes.items():
        for ref in item.get("references", []):
            if ref in indegree and ref != path:
                indegree[ref] += 1
                
    roots = [p for p, deg in indegree.items() if deg == 0]
    if not roots:
        if nodes:
            roots = [list(nodes.keys())[0]]
        else:
            return

    tree = { p: [] for p in nodes }
    visited = set()
    
    queue = deque(roots)
    visited.update(roots)
    
    while queue:
        current = queue.popleft()
        for child in nodes[current].get("references", []):
            if child in nodes and child not in visited:
                visited.add(child)
                tree[current].append(child)
                queue.append(child)
                
    values = {}
    
    def compute_size(node):
        size = nodes[node].get("narSize", 0)
        for child in tree[node]:
            size += compute_size(child)
        values[node] = size
        return size
        
    for r in roots:
        compute_size(r)
        
    rank = 1
    
    print("# HELP nix_flamegraph Nix store closure nested set flame graph")
    print("# TYPE nix_flamegraph gauge")
    
    total_val = sum(values[r] for r in roots)
    print(f'nix_flamegraph{{rank="{rank:05d}",level="0",label="CLOSURE_ROOT",self="0"}} {total_val}')
    rank += 1
    
    def walk(node, level):
        nonlocal rank
        self_size = nodes[node].get("narSize", 0)
        val = values[node]
        label = node.split("/")[-1].replace('\\', '\\\\').replace('"', '\\"')
        
        print(f'nix_flamegraph{{rank="{rank:05d}",level="{level}",label="{label}",self="{self_size}"}} {val}')
        rank += 1
        
        for child in tree[node]:
            walk(child, level + 1)
            
    for r in roots:
        walk(r, 1)

if __name__ == "__main__":
    main()
