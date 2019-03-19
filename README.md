# Docker based image for mysql


## Support development
- [paypal](https://paypal.me/kiorky)

## corpusops/mysql (CURRENT)
### Description
This setups a nginx reverse proxy on http/https that forward requests
to an underlying mysql worker.

This repository produces all those docker images:
- [corpusops/mysql](https://hub.docker.com/r/corpusops/mysql/)

### Volumes
- We use two main volumes!
    - a volume ``setup`` to share a configuration file to reconfigure fles
    - a volume ``data`` to store user data

#### Initialise setup volume
- To reconfigure any setting upon container (re)start, create/edit ``/setup/reconfigure.yml``
    - See [defaults](/ansible/roles/mysql/defaults/main.yml)

    ```sh
    mkdir -p local/setup
    cat >local/setup/reconfigure.yml << EOF
    ---
    setting: value
    ```

- To configure (add/modify/remove) new roles, db, & privs (resp. in this order),  we use custom corpusops modules which all wraps ansible official modules:
   - [corpusops.roles/mysql_role](https://github.com/corpusops/roles/tree/master/mysql_role)
   - [corpusops.roles/mysql_db](https://github.com/corpusops/roles/tree/master/mysql_db)
- Exemple

    ```yaml
    cops_mysql__roles:
    - name: dbuser
      # generate/use password inside file: ./local/config/pwd_dbuser
      password: foo
    cops_mysql__databases:
    - db: db
      owner: dbuser
    - db: db3
      state: absent
    cops_mysql__privs:
    - roles: dbuser
      database: db2
      type: database
      privs: ALL

    ```

- If you need to tune pgsql, you can add something to ``/setup/reconfigure.yml`` this way:

    ```yaml
    ---
	corpusops_services_db_mysql_mode: myproject
	corpusops_services_db_mysql_modes_myproject:
	  number_of_table_indicator: 1000
	  innodb_flush_method: 'O_DIRECT'
	  innodb_flush_log_at_trx_commit: 2
	  nb_connections: 250
	  memory_usage_percent: 20
    cops_mysql_sysctls:
    - kernel.shmall: 4026531840
    - kernel.shmmax: 16106127360
    ```

#### Initialise user data volumes
- You need to preseed some volumes from your image before running it
    - db

        ```sh
        mkdir -p local/db
        docker run --rm  -v $PWD/local/db:/ldb --entrypoint rsync \
            corpusops/mysql:9.6.5 \
            "/var/lib/mysql/" "/ldb/" \
           -av --delete
        ```

    - data

        ```sh
        mkdir -p local/data
        docker run --rm  -v $PWD/local/data:/ldata --entrypoint rsync \
            corpusops/mysql:9.6.5 \
            "/srv/projects/mysql/data/" "/ldata/" \
            -av --delete --exclude "pwd_*" --delete-excluded
        ```

### Run this image through docker
- To pull & run this image (PRODUCTION) <br/>
  Note that The folllowing command implicitly create 2 volumes against local directories and the goal
  is to prepopulate the directories from the image content on the first run.<br/>
  Indeed, the -v option does not feed host directories, even if empty from an image content.

    ```sh
    # docker pull corpusops/mysql:<TAG>
    docker pull corpusops/mysql:9.6.5
    docker run \
      --name=my-mysql-container \
      -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
      -v $(pwd)/local/setup:/setup:ro \
      -v "$(pwd)/local/data:/srv/projects/mysql/data" \
      -v "$(pwd)/local/db:/var/lib/mysql" \
      --security-opt seccomp=unconfined \
      -P -d -i -t corpusops/mysql:9.6.5
    ```

- In development, you can add the following knob to indicate that you want to
  edit files.

    ```sh
    -e SUPEREDITORS=$(id -u)
    ```

### Build this image
- Install ``hashicorp/packer`` && ``docker``
- get the code
- run ``./bin/build.sh``

### Image provision notes
- See ``.ansible``, the image is (re)-configured using ansible.

### A note on file rights
- Docker file rights are a nightmare for developers
- We provide a very way to use, specially when you are on localhost,<br/>
  activly developping  your app to edit the files of the container,<br/>
  thanks to POSIX ACLS.
- You need two things to configure your app (normally good by dedfault):
    - ``cops_mysql_supereditors_paths`` Tell which paths will be "opened" to the outside user(s) if default does not suit your need
    - ``cops_mysql_supereditors`` Tell which user(s), (attention **UIDS**).<br/>
      The aforementioned command to launch container includes the ``SUPEREDITORS`` env var configured with the loggued in user
- Those settings can be overriden via ``/setup/reconfigure.yml``
- File rights are enforced upon container (re-)start
- If file rights are messed up too much, you can try this to enforce them

    ```sh
    docker exec -e SUPEREDITORS="$(id -u)" -ti <mycontainer> bash
    /srv/projects/<myproject>/fixperms.sh
    ```

## ansible
- Docker uses the [mysql role](.ansible/roles/mysql) underthehood which
  is generic and is not docker specific.
- You may use directly this role to provision mysql on another host type.
- This code the raw [corpusops.roles/mysql role](https://github.com/corpusops/roles/tree/master/services_db_mysql)

### Steps to create cops docker compliant images
- We use via  bin/build.sh which launch [docker_build_chain](https://github.com/corpusops/corpusops.bootstrap/blob/master/hacking/docker_build_chain.py) ([doc](https://github.com/corpusops/corpusops.bootstrap/blob/master/doc/docker_build_chain.md#sumup-steps-to-create-corpusops-docker-compliant-images))



## USE/Install with makina-states
- makina-state deployment (legacy) can be found in .salt

### Exemple pillar

```yaml

  makina-projects.pgsql:
   data:
    backup_disabled: false
    pgver: 9.6
    mail: sysadmin@foo.com
    pg_optim:
      #./pgtune/pgtune -i /etc/mysql/9.5/main/mysql.conf -M $((15842612*1024))
      - default_statistics_target = 100
      - maintenance_work_mem = 960MB
      - checkpoint_completion_target = 0.9
      - effective_cache_size = 11GB
      - work_mem = 72MB
      - shared_buffers = 3840MB
    sysctls:
      - kernel.shmall: 4026531840
      - kernel.shmmax: 16106127360
    databases:
      - x:
          password: "x"
          user: x
```
     



