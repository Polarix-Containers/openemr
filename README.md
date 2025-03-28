# openemr

![Build, scan & push](https://github.com/Polarix-Containers/openemr/actions/workflows/build-7.0.3.yml/badge.svg)

### Features & usage
- Built on the [official image](https://github.com/openemr/openemr-devops) to be used as a drop-in replacement.
- Removed certbot. You should be using a separate container instead.
- Unprivileged image: you should check your volumes' permissions (eg `/data`), default UID/GID is 200007. 

### Licensing
- Licensed under GPL 3 to comply with licensing by OpenEMR.
- Any image built by Polarix Containers is provided under the combination of license terms resulting from the use of individual packages.
