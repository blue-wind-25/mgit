COPY_NAME=mgit-`date +'%Y%m%d-%H%M'`

echo

echo -e "Copying the project tree (excluding  the '.git' directory) ..."
cd ..
rsync -av --exclude='.git' mgit/ "$COPY_NAME/"
echo

echo -e "Archiving files from the copied project tree ..."
tar -cjvpf $COPY_NAME.tar.bz2 $COPY_NAME > /dev/null
echo -e "Done '$COPY_NAME.tar.bz2'"

echo
