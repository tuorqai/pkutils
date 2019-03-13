#
# Copyright (c) 2019 Valery Timiriliyev timiriliyev@gmail.com
# 
# This software is provided 'as-is', without any express or implied
# warranty. In no event will the authors be held liable for any damages
# arising from the use of this software.
# 
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
# 
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
#

# -1: first one is older
#  0: versions are equal
#  1: first one is newer
function compare_versions(v1, v2,    i, n, n1, n2, a1, a2) {
    n1 = split(v1, a1, /\./);
    n2 = split(v2, a2, /\./);

    if (n1 >= n2) {
        n = n1;
    } else {
        n = n2;
    }

    for (i = 1; i <= n; i++) {
        if (a1[i] > a2[i]) {
            return 1;
        } else if (a1[i] < a2[i]) {
            return -1;
        }
    }

    return 0;
}
