# 编译内核 (-j$NPROC, ThinLTO)
cd "$KERNEL_DIR"

make $KFLAGS -j"$NPROC" Image
