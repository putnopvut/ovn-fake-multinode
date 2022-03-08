set -x

./ovn_cluster.sh stop
CREATE_FAKE_VMS=no GW_COUNT=0 CHASSIS_COUNT=1 ./ovn_cluster.sh start

docker exec ovn-central ovn-nbctl ls-add public

# r1
docker exec ovn-central ovn-nbctl lr-add r1
docker exec ovn-central ovn-nbctl lrp-add r1 r1_public 00:de:ad:ff:0:1 172.16.0.1/16
docker exec ovn-central ovn-nbctl lrp-add r1 r1_s1 00:de:ad:fe:0:1 173.0.1.1/24
docker exec ovn-central ovn-nbctl lrp-set-gateway-chassis r1_public ovn-chassis-1

docker exec ovn-central ovn-nbctl lb-add r1_lb 30.0.0.1 172.16.0.102
docker exec ovn-central ovn-nbctl lr-lb-add r1 r1_lb
docker exec ovn-central ovn-nbctl ls-add s1

# s1 - r1
docker exec ovn-central ovn-nbctl lsp-add s1 s1_r1
docker exec ovn-central ovn-nbctl lsp-set-type s1_r1 router
docker exec ovn-central ovn-nbctl lsp-set-addresses s1_r1 router
docker exec ovn-central ovn-nbctl lsp-set-options s1_r1 router-port=r1_s1

# s1 - vm1
docker exec ovn-central ovn-nbctl lsp-add s1 vm1
docker exec ovn-central ovn-nbctl lsp-set-addresses vm1 "00:de:ad:01:0:1 173.0.1.2"

docker exec ovn-central ovn-nbctl lsp-add public public_r1
docker exec ovn-central ovn-nbctl lsp-set-type public_r1 router
docker exec ovn-central ovn-nbctl lsp-set-addresses public_r1 router
docker exec ovn-central ovn-nbctl lsp-set-options public_r1 router-port=r1_public nat-addresses=router
 
docker exec ovn-central ovn-nbctl lr-add r2
docker exec ovn-central ovn-nbctl lrp-add r2 r2_public 00:de:ad:ff:0:2 172.16.0.2/16
docker exec ovn-central ovn-nbctl lrp-add r2 r2_s2 00:de:ad:fe:0:2 173.0.2.1/24
docker exec ovn-central ovn-nbctl lr-nat-add r2 dnat_and_snat 172.16.0.102 173.0.2.2
docker exec ovn-central ovn-nbctl lrp-set-gateway-chassis r2_public ovn-chassis-1

docker exec ovn-central ovn-nbctl ls-add s2

# s1 - r1
docker exec ovn-central ovn-nbctl lsp-add s2 s2_r2
docker exec ovn-central ovn-nbctl lsp-set-type s2_r2 router
docker exec ovn-central ovn-nbctl lsp-set-addresses s2_r2 router
docker exec ovn-central ovn-nbctl lsp-set-options s2_r2 router-port=r2_s2

# s1 - vm1
docker exec ovn-central ovn-nbctl lsp-add s2 vm2
docker exec ovn-central ovn-nbctl lsp-set-addresses vm2 "00:de:ad:01:0:2 173.0.2.2"

docker exec ovn-central ovn-nbctl lsp-add public public_r2
docker exec ovn-central ovn-nbctl lsp-set-type public_r2 router
docker exec ovn-central ovn-nbctl lsp-set-addresses public_r2 router
docker exec ovn-central ovn-nbctl lsp-set-options public_r2 router-port=r2_public nat-addresses=router

docker exec ovn-chassis-1 ip netns add vm1
docker exec ovn-chassis-1 ovs-vsctl add-port br-int vm1 -- set interface vm1 type=internal
docker exec ovn-chassis-1 ip link set vm1 netns vm1
docker exec ovn-chassis-1 ip netns exec vm1 ip link set vm1 address 00:de:ad:01:00:01
docker exec ovn-chassis-1 ip netns exec vm1 ip addr add 173.0.1.2/24 dev vm1
docker exec ovn-chassis-1 ip netns exec vm1 ip link set vm1 up
docker exec ovn-chassis-1 ovs-vsctl set Interface vm1 external_ids:iface-id=vm1

docker exec ovn-chassis-1 ip netns add vm2
docker exec ovn-chassis-1 ovs-vsctl add-port br-int vm2 -- set interface vm2 type=internal
docker exec ovn-chassis-1 ip link set vm2 netns vm2
docker exec ovn-chassis-1 ip netns exec vm2 ip link set vm2 address 00:de:ad:01:00:02
docker exec ovn-chassis-1 ip netns exec vm2 ip addr add 173.0.2.2/24 dev vm2
docker exec ovn-chassis-1 ip netns exec vm2 ip link set vm2 up
docker exec ovn-chassis-1 ovs-vsctl set Interface vm2 external_ids:iface-id=vm2

docker exec ovn-chassis-1 ip netns exec vm1 ip route add default via 173.0.1.1
docker exec ovn-chassis-1 ip netns exec vm2 ip route add default via 173.0.2.1

docker exec ovn-central ovn-nbctl lr-nat-add r1 dnat_and_snat 172.16.0.101 173.0.1.2 vm1 00:00:00:01:02:03
