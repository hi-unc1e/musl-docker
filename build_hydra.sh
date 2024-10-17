# docker build . -t musl_docker
# docker run -it yingdao/musl_docker
# bash build_hydra.sh
git clone https://github.com/vanhauser-thc/thc-hydra
cd thc-hydra && git checkout v9.5
echo "remove /usr/include in `./configure`#163 " && sed -i '163s|/usr/include||' ./configure

# add RDP module deps
apt-get install -y libfreerdp2-2 freerdp2-dev
make clean
export C_INCLUDE_PATH=/usr/include/x86_64-linux-musl/:/usr/include/x86_64-linux-gnu/openssl/:/musl/include/openssl/:/volume/freerdp-3.8.0/winpr/include:/usr/include/libssh/:/usr/lib/x86_64-linux-gnu/:/usr/include/
export  CC="/usr/bin/musl-gcc -static --static" 
./configure --disable-xhydra CC="/usr/bin/musl-gcc -static --static" 
make -j4

