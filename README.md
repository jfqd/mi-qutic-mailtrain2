# mi-qutic-mailtrain2

This repository is based on [Joyent mibe](https://github.com/jfqd/mibe).

## description

mailtrain2 lx-brand image for SmartOS

## Build Image

```
cd /opt/mibe/repos
/opt/tools/bin/git clone https://github.com/jfqd/mi-qutic-mailtrain2.git
LXBASE_IMAGE_UUID=$(imgadm list | grep qutic-lx-base | tail -1 | awk '{ print $1 }')
TEMPLATE_ZONE_UUID=$(vmadm lookup alias='qutic-lx-template-zone')
../bin/build_lx $LXBASE_IMAGE_UUID $TEMPLATE_ZONE_UUID mi-qutic-mailtrain2 && \
  imgadm install -m /opt/mibe/images/qutic-mailtrain2-*-imgapi.dsmanifest \ 
                 -f /opt/mibe/images/qutic-mailtrain2-*.zfs.gz
```