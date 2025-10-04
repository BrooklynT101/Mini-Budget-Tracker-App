## Build Downloads (measured on 08-09-2025)

### Mehod: Measured on each VM using:

du -sh /srv/api/node_modules
du -sh /var/cache/apt/archives
du -sh /var/lib/apt/lists


Results:

| VM  | node\_modules | apt archives | apt lists | Subtotal       |
| --- | ------------- | ------------ | --------- | -------------- |
| api | 5.5 MB        | 33 MB        | 239 MB    | **\~277.5 MB** |
| web | —             | 2.4 MB       | 239 MB    | **\~241.4 MB** |
| db  | —             | 30 MB        | 239 MB    | **\~269 MB**   |


First build (clean) total across all VMs: ~0.79 GB

Subsequent redeploys:

- If provisioning does not run apt-get update again and no package.json changes: near-zero additional downloads (services just restart).

- If provisioning does run apt-get update each time: expect ~239 MB per VM re-downloaded for apt lists (~0.72 GB across 3 VMs), even if no packages change.

- API deps will download again only if package.json/package-lock.json changed (still small; baseline was 5.5 MB).