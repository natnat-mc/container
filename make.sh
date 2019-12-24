#!/bin/sh
moonc container.moon
echo "#!/usr/bin/env lua" > shebang.txt
cat shebang.txt container.lua > container
chmod +x container
