#!/usr/bin/env python3

import sys
import re

import vpppath

_vppdir = vpppath.g_vpp_srcdir
_vpproot = vpppath.g_vpp_native_root
_vpppluginpath = vpppath.g_vpp_pluginpath
_vppldpath = vpppath.g_vpp_ldpath

for line in sys.stdin:
    line=re.sub("%VPPDIR%", _vppdir, line)
    line=re.sub("%VPPROOT%", _vpproot, line)
    line=re.sub("%VPPPLUGINPATH%", _vpppluginpath, line)
    line=re.sub("%VPPLDPATH%", _vppldpath, line)

    print(line, end='')
