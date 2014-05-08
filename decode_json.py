#!/usr/bin/env python
import sys
import json

j = json.load(sys.stdin)

json.dump(j, sys.stdout, ensure_ascii=False, sort_keys=True, indent=2)
