FROM nginx:1.23.2
COPY build/asciidoc/html5 /usr/share/nginx/html
COPY build/asciidoc/pdf /usr/share/nginx/html/pdfs
