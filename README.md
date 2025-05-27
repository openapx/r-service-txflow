# txflow
A simple storage REST API for the Flow data repository written in R

The basic principle of the Flow data repository is to provide version controlled
storage of data similar to that of a code repository without inheriting many of 
the complexities of trying to use GitHub or GitLab with data files.

Flow and txflow is based on the concept of repositories and snapshots. A 
repository is single-level non-hierarchical container of data, meaning it does 
not support subfolders and subdirectories. 

Data is stored as blobs, binary objects, using the content SHA-1 as the blob name. 
This provides both natural versioning and de-duplication.

A repository snapshot is a collection of named data entries that are stored 
within the data repository. The entry name within a snapshot would be equivalent
to a file name, such that different snapshots can use different naming conventions
for the same data, or blob, depending on the use case.

The txflow REST API is the storage engine in the Flow data repository and is 
intended for synchronizing with and transferring data to and from the data 
repository by agents, essentially a classic data mover. 

The txflow REST API is not intended for direct access by individual users. 

<br/>

### Repositories and Snapshots and the Work Area
The txflow REST API implements a commit-style workflow to upload data and create 
snapshots via a work area that is subsequently committed to the repository.

A work area is created specifying a new or existing snapshot. If the snapshot 
exists, the work area is initiated with the snapshot specification. Existing
snapshot data files or blobs are not staged in the work area.

All data files or blobs are uploaded to the work area. In addition, a reference
to a data file or blob that exists in the repository can be added, either using
the repository resource or a snapshot reference.

Similarly a data file or blob can be deleted from the work area.

Once the work area is deemed complete and ready, it is committed to the repository.

The work area can be committed to a new snapshot within the same repository as
was used when the work area was created. This permits one snapshot acting as a 
template for a new snapshot.

If the commit is successful, the work area is deleted. A failed commit retains 
the work area.


<br/>
<br/>


### Dependencies
The txflow service depends on the R packages cxapp for configuration, logging and 
API authentication and cxaudit for audit trail. Some of those topics will be
briefly mentioned here but please refer to the respective package documentation 
for additional details.

- cxapp package https://github.com/cxlib/r-package-cxapp
- cxaudit package https://github.com/cxlib/r-package-cxaudit

<br/>

### Getting Started
The txflow service is available either pre-built container image on Docker Hub or as the R package txflow.service.

<br/>


#### Container Image on Docker Hub
The txflow service container image will be available for multiple Linux operating system flavors and R versions 
depending on your organization preference.

The container images are available on Docker Hub at https://hub.docker.com/repository/docker/openapx/txflowservice/general.

For now, the current effort is focused on Ubuntu and R version 4.4.3.

```
docker pull openapx/txflow.service:<OS>-latest-<R version>
```

or choose a particular container image version.

<br/>

##### Service Start
The service is installed in the directory `/opt/openapx/apps/txflow` (`APP_HOME`).

The service is started by the standard entry point script `/entrypoint.sh` with 
no arguments.

Start up options are set in the `APP_HOME/service.properties` file.

`WORKERS` specifies the number of parallel R Plumber worker sessions to launch. 
A worker equates to the number of requests the service can serve concurrently. 
Note that Plumber and the way the API has been written, it is one request per R session.

<br/>


##### Service Configuration
The service configuration options are set in the `APP_HOME/app.properties` file
and includes a default configuration (below) to quickly get started.

There are three standard directories.

- `/data` for service logs and other service data files
- `/.vault` used for a local internal vault

<br/>

```
# -- default service configuration


# -- txflow service

# - local storage enabled
TXFLOW.STORE = LOCAL

# - parent directory for data repositories and their snapshots
TXFLOW.DATA = /data/txflow/repos

# - txflow work area
TXFLOW.WORK = /data/txflow/work



# -- auditor
#    note: audit trail service

# - enable auditor service
#   note: use disable or disabled to disable the auditor service
#   note: see https://github.com/openapx/r-service-auditor
AUDITOR = enabled

# - this environment as known in audit records
#   note: this is only a reference string but should be kept consistent for
#         identifying environments across records
AUDITOR.ENVIRONMENT = txflow.example.com

# - auditor URL
#   note: this also includes the port if non-standard
AUDITOR.URL = http://auditor.example.com

# - auditor access token
#   note: environmental variables are supported
#   note: local and Azure Key vault is support
#   note: for further details see Configuration section in the cxapp package
#         https://github.com/cxlib/r-package-cxapp 
AUDITOR.TOKEN = <token>

# - auditor fail cache
#   note: when the auditor service is enabled and not available or reachable,
#         records are written to the fail cache
AUDITOR.FAILCACHE = /data/txflow/auditor-fail-cache



# -- logging 
LOG.PATH = /data/txflow/logs
LOG.NAME = txflow
LOG.ROTATION = month



# -- API authorization
#    note: uses vault configuration below
#    note: access tokens should be created 
#    note: see reference section Authentication in the txflow service API reference
#    note: see section API Authentication in the cxapp package https://github.com/cxlib/r-package-cxapp 
#    note: service - utility /opt/openapx/utilities/vault-apitoken-service.sh <service name>
API.AUTH.SECRETS = /api/auth/txflow/services/*

# - named list of users and services acting as admins
#   note: space delimited list of principals associated with access tokens 
API.ADMINS = service001



# -- vault configuration
#    note: using a local vault
#    note: Azure Key Vault also supported
VAULT = LOCAL
VAULT.DATA = /.vault

```

<br/>

##### Creating API Bearer Token
The txflow container image is pre-configured to use the local vault to store encoded authentication
tokens that can be used to authenticate with the API.

The default configuration is to look for registered tokens with prefix 
`/api/auth/txflow/services` in the local vault.

The utility vault API service token utility can be used to create a token
associated with a named service.


```
/opt/openapx/utilities/vault-apitoken-service.sh <service name>
```

For further details, see API Authentication section for the cxapp R package.


<br/>
<br/>


####  As an R Package
Download and install the latest release of txflow.service from https://github.com/openapx/r-service-txflow/releases/latest

You can also install the latest release directly using install.packages().

```
# -- install dependencies
#    note: see DESCRIPTION for package dependencies
#    note: cxapp can be found at https://github.com/cxlib/r-package-cxapp
#    note: cxaudit can be found at https://github.com/cxlib/r-package-cxaudit

#    note: change the version 0.0.0 to the appropriate version
install.packages( "https://github.com/openapx/r-service-txflow/releases/download/v0.0.0/txflow.service_0.0.0.tar.gz", type = "source", INSTALL_opts = "--install-tests" )
```
<br/>

Please the default configuration for the txflow service container image for required configuration options.


<br/>
<br/>


### API Refernce

<br/>

#### Authentication
The API uses Bearer tokens to authenticate a connection request using the standard header.

```
Authorization: Bearer <token>
```
See `cxapp::cxapp_authapi()` and the API Authentication section for the cxapp package for further details and configuration options.


<br/>
<br/>


##### List Repositories

```
GET  /api/repositories
```
Returns a list of repositories

The returned records are in the format of a JSON array of repository names.

```
[ 
  "repository-1",
  "repository-2",
  ...
]
```


<br/>
<br/>


##### Create Repository

```
PUT  /api/repositories/<repository>
```
Returns the created repository name

The repository name  
- consists of letters a-z, digits 0-9 and punctuation dash `-`
- starts and ends with a letter or digit
- all dashes `-` must be preceded and followed by letter or digit
- is between 3 and 63 characters in length

The returned record is in the format of a JSON array with the new repository name 
as the only entry.

```
[ 
  "new-repository"
]
```

The principal associated with the authorization bearer token should be listed
in the configuration property `API.ADMINS`. If the requestor is not an API admin, 
HTTP status code 403 with the message `Not permitted` is returned.




<br/>
<br/>


##### List Repository Snapshots

```
GET  /api/repositories/<repository>/snapshots
```
Returns a list of snapshots for a given repository.

The returned records are in the format of a JSON array of snapshot references.

```
[ 
  "repository-1/snapshot-01",
  "repository-1/snapshot-02",
  ...
]
```

<br/>
<br/>


##### Get Repository Snapshot Specification

```
GET  /api/repositories/<repository>/snapshots/<snapshot>
```

Returns the snapshot specification for a given snapshot in a specified repository.
Note that a snapshot is created through a work area.

The returned record is in the format of a JSON object.

```
{
  "version": "0.1",
  "name": "<snapshot name>",
  "repository": "<repository>",
  "contents": [
    {
      "type": "<content type>",
      "class": "<content class>",
      "reference": "<content reference>",
      "sha": "<SHA-1 of content>",
      "blobs": "<repository blob name>",
      "mime": "<content mime/file extension>",
      "name": "<content name within snapshot>"
    },
    ...
  ]
}
```

The `version` is an internal schema version number.

The `name` property is the snapshot name and the `repository` property refers to
the snapshot's parent repository.

Each data file or blob included in the snapshot is listed in the `contents` array.
The attributes for the file or blob is are defined within the context of the 
snapshot and may differ from those attributes defined for snapshots where the same
file or blob is included.

See the API endpoint for Add/Upload Data File or Blob to a Work Area for the
further details on the data file and blob properties.


<br/>
<br/>


#### Get Content as a Repository Resource

```
GET /api/repositories/<repo>/<reference>
```

Retrieves and downloads a file or blob by its repository reference, i.e. the 
`blobs` entry regardless if the file or blob is a member of a snapshot.

The request requires that the Content-Type header of the request is equal to
`application/octet-stream`. 


<br/>
<br/>



#### Get Content as a Repository Snapshot Resource

```
GET /api/repositories/<repo>/snapshots/<snapshot>/<reference>
```

Retrieves and downloads a file or blob by its repository snapshot reference, 
i.e. the `blobs` entry or the snapshot blob `name` property. The resource 
must be a member of the snapshot.

The request requires that the Content-Type header of the request is equal to
`application/octet-stream`. 


<br/>
<br/>



#### Create a New Work Area
```
GET /api/work/<repository>/<snapshot>
```

Creates a new work area for a specified `repository` and `snapshot`. If the 
snapshot exists in the specified repository, the work area is initialized with
the snapshot specification. Any existing data files or blobs for the specification
is not staged in the work area.

If the snapshot does not exist, a new snapshot specification is created in the
work area.

The snapshot name  
- consists of letters a-z, digits 0-9 and punctuation dash `-` and underscore `_`
- starts and ends with a letter or digit
- all dashes `-` and underscores `_` must be preceded and followed by letter or digit
- is between 3 and 256 characters in length

The returned record is in the format of a JSON array with the new work area name 
as the only entry.


```
[ 
  "new-workarea"
]
```

<br/>
<br/>



#### Add/Upload Data File or Blob to a Work Area 
```
PUT /api/work/<work>/<name>
PUT /api/work/<work>/<name>?<options>
```

Adds or uploads data file or blob to the specified work area.

The request requires that the Content-Type header of the request is equal to
`application/octet-stream`. 

The `name` is the resource name used to identify the uploaded file snapshot within
the snapshot, equivalent to a file name.

Additional options can be specified as part of the query string.

The `type` option refers to the data file or blob type. Default is `datafile`.

The `class` can be further used to identify a subclass of `type`.

`referernce` is the common reference to the uploaded file such that given the 
`type`, `class` and `reference`, like repository entries can be associated. An 
example could be a repository entry with `type` equal to `datafile`, `class` being
`sdtm` and the `reference` equal to `ae` to represent an AE SDTM data file.

If `reference` is not specified, the value of `name` without the extension is used.

`mime` is a short reference to the content format. Default is the extention of `name`.

The returned record is in the format of a JSON object.

```
{
  "type": "<type>",
  "class": "<class>",
  "reference": "<reference>",
  "sha": "<SHA-1 of uploaded data file or blob>",
  "blobs": "<resource name>",
  "mime": "<mime>",
  "name": "<name>"
}
```

The `sha` SHA-1 message digest if generated after the upload and prior to the 
data file or blob being added to the work area and thus before it is stored 
within the repository.

The `blobs` property is the resource name within the data repository. 

<br/>
<br/>



#### Add Existing Data File or Blob to a Work Area 
```
PATCH /api/work/<work>/<reference>
PATCH /api/work/<work>/<reference>?<options>
```

Adds an existing data file or blob to the specified work area from the 
repository associated with the work area. 

If no options are specified, `reference` is assumed to represent a repository
resource, i.e. a blob reference.

If the option `snapshot` is specified, the `reference` is assumed to be either
a `blob` in or the `name` of an entry of `snapshot`. The snapshot must exist
in the repository associated with the work area.

An existing data file or blob can be added to the work area snapshot as a 
different named item by specifying the new name using the `name` option. All 
other data file or blob attributes are retained from the source `snapshot`.

The returned record is in the format of a JSON object.

```
{
  "type": "<type>",
  "class": "<class>",
  "reference": "<reference>",
  "sha": "<SHA-1 of data file or blob>",
  "blobs": "<reosource name>",
  "mime": "<mime>",
  "name": "<name>"
}
```

<br/>
<br/>



#### Drop Data File or Blob from a Work Area 
```
DELETE /api/work/<work>/<reference>
```

Deletes an existing data file or blob from the specified work area. 

The reference is either the data file or blob `blobs` reference or work area
`name`.

The returned record is in the format of a JSON array with the result of the 
operation represented as a boolean.

```
[ 
  true
]
```

<br/>
<br/>



#### Commit Work Area 
```
PUT /api/commit/<work>
PUT /api/commit/<work>?<options>
```
Commits the state of the current work area to the work area repository.

The option `snapshot` commits the work area to the specified snapshot. If the
specified snapshot does not exist, a new snapshot is created in the repository.

This option permits a work area to be initiated with an existing or new empty 
snapshot as a template for creating and committing a new snapshot.

The returned record is in the format of a JSON array with the commit scope.

```
[ 
  "<repository>/<snapshot>"
]
```

<br/>
<br/>


#### Service Information
```
GET /api/info
```
Get service information.

The returned record is in the format of a JSON object.

```
{
  "service": "txflow",
  "version": "<txflow version>",
  "repositories": {
    "configuration": {
      "txflow.store": "<storage service>",
      "txflow.data": "<repository parent directory>",
      "txflow.work": "<work area parent directory>"
    }
  },
  "auditor": {
    "service": "<audit service enabled>",
    "configuration": {
      "auditor.environment": "<this environment identified as with auditor>",
      "auditor.url": "<auditor URL + port>",
      "auditor.token": "<set or unset>",
      "auditor.failcache": <path to auditor fail cache>
    }
  }
}
```


If the auditor service is disabled, the auditor configurtion may not be displayed.



<br/>
<br/>


#### Ping
```
GET /api/ping
```
The ping API endpoint is a simple method to ensure that the service is reachable
and returns status code 200.

Authentication is not required.


<br/>
<br/>

### Configuration
The service relies on the cxapp package for configuration, logging and authorizing 
API requests and the cxaudit package for auditing and audit trail function.

txflow repositories and snapshots stored on the local file system but
support for Azure block storage will be added in the near future.


<br/>


#### Application Configuration
The configuration is defined through the `app.properties` file located in one 
of the following directories.

- current working directory
- the `$APP_HOME/config` or `$APP_HOME`directory where `$APP_HOME` is an environmental variable
- first occurrence of the {txflow.service} package installation in `.libPaths()`

See `cxapp::cxapp_config()` for further details.

<br/>


#### Local Storage
The following app properties are used for configuring local file system storage.

- `TXFLOW.STORE` equal to `LOCAL`
- `TXFLOW.DATA` is the parent directory for data repositories
- `TXFLOW.WORK` is the parent directory for work areas


<br/>


#### Service Logs
The services relies on `cxapp::cxapp_log()` to log requests.

The logging mechanism supports the following configuration options.

- `LOG.PATH` as the parent directory for log files
- `LOG.NAME` is the prefix log name
- `LOG.RORTATION` defines the period of log file rotation. Valid rotations are
   `YEAR`, `MONTH` and `DAY`. The rotation period follows the format four digit
   year and two digit month and day.
   
 
See cxapp::cxapp_log() for additional details.


