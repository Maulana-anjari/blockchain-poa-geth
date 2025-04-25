# Non-Signer 1 (Bootnode)
echo "${NONSIGNER1_PASSWORD}" > config/nonsigner1.pass
docker run --rm -it -v "$(pwd)/data/nonsigner1/keystore:/root/.ethereum/keystore" -v "$(pwd)/config/nonsigner1.pass:/root/password.txt" \
  ethereum/client-go:alltools-v1.13.15 geth account new --keystore /root/.ethereum/keystore --password /root/password.txt
rm config/nonsigner1.pass

# Non-Signer 2
echo "${NONSIGNER2_PASSWORD}" > config/nonsigner2.pass
docker run --rm -it -v "$(pwd)/data/nonsigner2/keystore:/root/.ethereum/keystore" -v "$(pwd)/config/nonsigner2.pass:/root/password.txt" \
  ethereum/client-go:alltools-v1.13.15 geth account new --keystore /root/.ethereum/keystore --password /root/password.txt
rm config/nonsigner2.pass

# Non-Signer 3
echo "${NONSIGNER3_PASSWORD}" > config/nonsigner3.pass
docker run --rm -it -v "$(pwd)/data/nonsigner3/keystore:/root/.ethereum/keystore" -v "$(pwd)/config/nonsigner3.pass:/root/password.txt" \
  ethereum/client-go:alltools-v1.13.15 geth account new --keystore /root/.ethereum/keystore --password /root/password.txt
rm config/nonsigner3.pass

# Non-Signer 4
echo "${NONSIGNER4_PASSWORD}" > config/nonsigner4.pass
docker run --rm -it -v "$(pwd)/data/nonsigner4/keystore:/root/.ethereum/keystore" -v "$(pwd)/config/nonsigner4.pass:/root/password.txt" \
  ethereum/client-go:alltools-v1.13.15 geth account new --keystore /root/.ethereum/keystore --password /root/password.txt
rm config/nonsigner4.pass

# Non-Signer 5
echo "${NONSIGNER5_PASSWORD}" > config/nonsigner5.pass
docker run --rm -it -v "$(pwd)/data/nonsigner5/keystore:/root/.ethereum/keystore" -v "$(pwd)/config/nonsigner5.pass:/root/password.txt" \
  ethereum/client-go:alltools-v1.13.15 geth account new --keystore /root/.ethereum/keystore --password /root/password.txt
rm config/nonsigner5.pass