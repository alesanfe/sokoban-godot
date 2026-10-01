#!/usr/bin/env python3
"""Punto de entrada compatible — el backend vive en `community/`.

Se mantiene este shim porque CI, tests E2E y docs invocan
`python server/community_server.py`; la implementación está en
server/community/{config,store,auth,verify,stats,routes,http_api,app}.py.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from community.app import main

if __name__ == "__main__":
    main()
