# ansible-fabric

## 功能

- 准备，
  - 独立云硬盘`/dev/vdb`，用于挂载`/var/lib/docker`，docker存储建议使用`overlay`
  - 独立云硬盘`/dev/vdc`，用于挂载`/hfc-data/`，其中
    - `/hfc-data/<容器节点名>/configtx`，用来存储各容器节点的配置文件
    - `/hfc-data/<容器节点名>/restore`，用来存储各容器节点的手工恢复脚本
    - `/hfc-data/<容器节点名>/data`，用来存储各peer容器节点的数据
- 安装前，自动清理目标机器，
  - 删除所有的fabric容器实例(不会删除monitor client实例)
  - 删除所有hyperledger fabric自动生成的镜像
  - 删除fabric节点产生的所有相关数据
- 安装跨区多节点的hyperledger fabric环境
  - 多节点<支持启用tls>：
    - 2x ca, 1x orderer, 4x peer, ~~1x couchdb~~, 1x monitor server
    - 每台云主机均部署1x nodeexport + 1x cadvisor
  - 节点部署结构如下

  ```bash
    Ansible_host:                   103.237.5.178 @ Huabei
        |---- monitor_server        103.237.5.178 @ Huabei
        |---- dnsmasq_server        103.237.5.178 @ Huabei
        |
        |---- ordererorg1orderer1:  113.209.68.126 @ Huabei
        |---- ca_peerorg1:          113.209.68.127 @ Huabei
        |---- peerorg1peer1:        113.209.68.128 @ Huabei
        |---- peerorg1peer2:        120.132.114.36 @ ${Huanan}
        |---- ca_peerorg2:          120.132.114.32 @ ${Huanan}
        |---- peerorg2peer1:        120.132.114.37 @ ${Huanan}
        |---- peerorg2peer2:        113.209.68.131 @ Huabei

  ```

- 安装后，
  - 设置备份 -- 自动设置cron任务，每天各容器的配置文件、恢复脚本及所有的数据
  - 设置监控 -- 自动添加所有客户端至monitor server，并添加相应的报警机制

- grafana的dashboard模板位于`ansible-fabric/grafana/`

## 版本

目前用来部署石颖同学的`snapshot build` 包含如下镜像及tag：

```bash
docker pull shiying/fabric-ca:x86_64-1.0.0-snapshot-f0f86b7
docker pull shiying/fabric-couchdb:x86_64-1.0.0-snapshot-56b6d12
docker pull shiying/fabric-orderer:x86_64-1.0.0-snapshot-56b6d12
docker pull shiying/fabric-peer:x86_64-1.0.0-snapshot-56b6d12
docker pull shiying/fabric-ccenv:x86_64-1.0.0-snapshot-56b6d12
docker pull hyperledger/fabric-baseimage:x86_64-0.3.0
docker pull hyperledger/fabric-baseos:x86_64-0.3.0


docker tag shiying/fabric-ca:x86_64-1.0.0-snapshot-f0f86b7 \
       hyperledger/fabric-ca:latest
docker tag shiying/fabric-couchdb:x86_64-1.0.0-snapshot-56b6d12 \
       hyperledger/fabric-couchdb:latest
docker tag shiying/fabric-orderer:x86_64-1.0.0-snapshot-56b6d12 \
           hyperledger/fabric-orderer:latest
docker tag shiying/fabric-peer:x86_64-1.0.0-snapshot-56b6d12 \
           hyperledger/fabric-peer:latest
docker tag shiying/fabric-ccenv:x86_64-1.0.0-snapshot-56b6d12 \
           hyperledger/fabric-ccenv:latest
docker tag shiying/fabric-ccenv:x86_64-1.0.0-snaps
hot-56b6d12 \
           hyperledger/fabric-ccenv:x86_64-1.0.0-snapshot-56b6d12
```

## 进展

- 多机部署测试`bash run_prod_playbook.sh` --> 通过
- 备份脚本测试 --> 通过
- 恢复脚本测试 --> 通过
- 监控及报警   --> 通过
- TLS启用/禁用 --> 通过

## 用法

1. 登陆`docker-registry`主机
1. 切换到playbook将要存放的目录，如
    ```bash
    mkdir -p /tmp/playbook/
    cd /tmp/playbook/
    ```
1. 通过git下载playbook
    ```bash
    git clone http://103.237.5.178:3000/fabric/ansible-fabric.git
    git checkout v1.0.0-1
    ```
1. 根据实际修改`inventories/prod/hosts`中的ip地址及角色分配。
1. 执行部署脚本：
    - prod环境， `bash run_prod_playbook.sh`
1. 各容器节点默认端口：
    - ca: 7054
    - orderer: 7050
    - peer: 7051、7053
    - grafana: 9095
    - prometheus: 9090
    - altermanager: 9093
    - nodeexporter: 9100
    - cadvisor: 8080
1. jcloud blockchain客户端需要更新`config.json`和相应的`certs`文件（如果启用tls的话）,如果客户端容器实例在本机，可以执行脚本`config_client_shiying.sh`进行配置
1. 每天定期备份容器节点的脚本位于每台容器节点的`/etc/cron.d/<容器名>-backup`
1. 每个容器的恢复脚本及配置信息位于每台容器节点的`/hfc-data/<容器名>/restore/`
1. 所有云主机及云主机上的容器均加入prometheus监控，默认设置邮件报警，默认邮件会发送至liuchenglong3@jd.com

## 关于容器恢复

在执行`/hfc-data/<容器名>/restore/run-<容器名>.sh`之前，需要确保：

- `/hfc-data/<容器名>/configtx/`已经存在并且数据完整
- `/hfc-data/<容器名>/restore/`已经存在并且数据完整
  - 根据节点信息，确保`hosts`文件中该节点的IP信息正确
  - 根据实际节点的信息，确认`env.list`中的必要更新
- 如果是peer节点，需要确保`/hfc-data/<容器名>/data/`已经存在并且数据完整
- 同时确保没有同名容器存在，在确认安全的前提下，执行`docker rm -f <容器名>`
