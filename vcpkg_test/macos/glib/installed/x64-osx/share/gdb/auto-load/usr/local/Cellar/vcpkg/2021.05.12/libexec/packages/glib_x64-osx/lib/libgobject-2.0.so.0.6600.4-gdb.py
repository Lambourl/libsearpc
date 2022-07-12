import sys
import gdb

# Update module path.
dir_ = '/usr/local/Cellar/vcpkg/2021.05.12/libexec/packages/glib_x64-osx/share/glib-2.0/gdb'
if not dir_ in sys.path:
    sys.path.insert(0, dir_)

from gobject_gdb import register
register (gdb.current_objfile ())
