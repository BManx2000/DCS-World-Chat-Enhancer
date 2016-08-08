#!/bin/bash

for i in `find mod_files/ -type f`; do
diff -Z $i "$(echo $i | sed "s#mod_files#/c/Program Files/Eagle Dynamics/DCS World 2 OpenAlpha#g")"
done
