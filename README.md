# Advantech Router Utilities
This repository contains various utilities for working with Advantech ICR series routers

## Python Wheels
ICR routers run on Armv7 (soft float), most python packages do not have prebuilt wheels available
for this architecture. We precompile some common packages and make wheels available [here](https://RockfieldTechnologiesAustralia.github.io/advantech-router-utilities/wheels).
The list of available packages is found in `python-wheels/package-list.txt`

To use the wheels for a specific python version and router version use:

Router App `v3`:

 `pip install mercuto-client --extra-index-url https://RockfieldTechnologiesAustralia.github.io/advantech-router-utilities/wheels/v3/simple/`

Router App `v4`:

 `pip install mercuto-client --extra-index-url https://RockfieldTechnologiesAustralia.github.io/advantech-router-utilities/wheels/v4/simple/`
