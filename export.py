import sys
import os
from galaxy_ie_helpers import put
arg1 = sys.argv[1]
arg2 = sys.argv[2]
put('%s' % arg1, file_type='%s' % arg2)
