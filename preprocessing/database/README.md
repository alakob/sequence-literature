# sequence-literature Database
This repository host a compressed postgreSQL dump of the sequence-literature database. The dump is located in initdb directory
This database can be loaded in your local postgreSQL database or explored in a provided containerized environment following the step below.

### Prerequisite:

- Docker
- Docker-compose

- ### build the image

In the repos directory run the following

```
Docker-compose up --build -d
```

- ### Access the database

Access pgadmin interface at http://localhost:5050

- Use the credentials found in the docker-compose file.

