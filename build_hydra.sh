# docker build . -t musl_docker
# docker run -it yingdao/musl_docker
# bash build_hydra.sh
git clone https://github.com/vanhauser-thc/thc-hydra
cd thc-hydra && git checkout v9.5
echo "remove /usr/include in `./configure`#163 " && sed -i '163s|/usr/include||' ./configure

make clean
./configure --disable-xhydra CC="/usr/bin/musl-gcc -static --static" C_INCLUDE_PATH=/usr/include/x86_64-linux-musl/
make -j4

