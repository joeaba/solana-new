# |source| this file

# curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
curl -sL https://raw.githubusercontent.com/creationix/nvm/v0.35.3/install.sh -o install_nvm.sh

#sudo apt install -y nodejs

npm install --global docusaurus-init
docusaurus-init

npm install --global vercel
