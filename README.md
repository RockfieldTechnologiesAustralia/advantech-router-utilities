# Advantech Router Utilities
This repository contains various utilities for working with Advantech ICR series routers

## Python Wheels
ICR routers run on Armv7 (soft float), most python packages do not have prebuilt wheels available
for this architecture. We precompile some common packages and make wheels available [https://RockfieldTechnologiesAustralia.github.io/advantech-router-utilities/](here).
The list of available packages is found in `python-wheels/package-list.txt`

To use the wheels for a specific python version and router version use:
 `pip install requests --extra-index-url https://RockfieldTechnologiesAustralia.github.io/advantech-router-utilities/3.12.9.v3/simple/`
Where `3.12.9.v3` is the python version and router app version installed on the router. E.g. python 3.12.9, using router app version v3.