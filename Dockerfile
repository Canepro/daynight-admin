# DayNight Admin - static site served by nginx
FROM nginx:alpine

# Remove default content and copy our static site
RUN rm -rf /usr/share/nginx/html/*
COPY . /usr/share/nginx/html/

# Expose HTTP
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
