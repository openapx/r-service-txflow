# txflow REST API
A simple storage REST API for the Flow data repository written in R

The basic principle of the Flow data repository is to provide version controlled
storage of data similar to that of a code repository without inheriting many of 
the complexities of trying to use GitHub or GitLab with data files.

Flow and txflow is based on the concept of repositories and snapshots. A 
repository is single-level non-hierarchical container of data, meaning it does 
not support subfolders and subdirectories. 

Data is stored as blobs, binary objects, using the content SHA-1 as the blob name. 
This provides both natural versioning and de-duplication.

It is extremely common that data is not stored as one single data file or blob, 
but spread across multiple data files and blobs that may represent individual
data domains, such Demography, Adverse Event, Laboratory Results, etc. in Life
Sciences. We therefore treat and manage most _data_ as a collection of individual
data domains.   

A repository snapshot is a named collection of data files and blobs that are stored 
within the data repository. The entry name within a snapshot would be equivalent
to a file name, such that different snapshots can use different naming conventions
for the same data, or blob, depending on the use case. See section related to
the _Snapshot Specification_ for further details.

The txflow REST API is the storage engine in the Flow data repository and is 
intended for synchronizing with and transferring data to and from the data 
repository by agents, essentially a classic data mover. 

The txflow REST API is not intended for direct access by individual users as it
knows nothing about permissions. It is left to the host environment where the
users are provided access to the downloaded and staged data to manage access
permission.

Direct user access to data repositories and snapshots will be provided through
the Flow REST API in a future release.

<br/>

### Repositories and Snapshots and the Work Area
The txflow REST API implements a commit-style workflow to upload data and create 
and edit snapshots via dedicated work areas. Once all updates are completed, 
the work area is committed to the repository.

A work area is created specifying a new or existing snapshot as a starting point.
If the snapshot exists, the work area is initiated with the snapshot specification.
Existing snapshot data files or blobs are not staged in the work area, only 
references to them.

All data files or blobs are uploaded to the work area. In addition, a reference
to a data file or blob that exists in the repository can be added, either using
the repository resource or a snapshot reference.

Similarly a data file or blob can be dropped from the work area.

Once the work area is deemed complete and ready, it is committed to the repository.

The work area can be committed to a new snapshot within the same repository as
was used when the work area was created. This permits one snapshot acting as a 
template for a new snapshot.

If the commit is successful, the work area is deleted. A failed commit retains 
the work area.

A data file or blob committed to the repository cannot be deleted in this 
release.

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
The txflow service is available as either a pre-built container image on Docker
Hub or as the R package txflow.service.

<br/>


#### Container Image on Docker Hub
The txflow service container image will be available for multiple Linux operating
system flavors and R versions depending on your organization preference.

The container images are available on Docker Hub at
https://hub.docker.com/repository/docker/openapx/txflowservice/general.

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

The txflow service utilizes nginx for load balancing and SSL termination.

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


# -- txflow service repository and snapshot storage

# - enable storage
#    note: LOCAL storage uses the local file system
#    note: AZUREBLOBS uses Azure Block Blob storage 
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
#   note: local and Azure Key vault is supported
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

Note that the txflow REST API also supports Azure Block Blob store as an alternative
to local file storage.

<br/>

##### Creating API Bearer Token
The txflow container image is pre-configured to use the local vault to store 
encoded authentication tokens that can be used to authenticate with the API.

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




### Conventions and Specifications
The Flow and txflow repository is primary based on the stored data files and blobs.
The majority of associated metadata is maintained by Flow, but the principle
information is also stored as specification files within the data repository 
to easily archive and restore data repositories.

The specifications are stored in JSON format.

<br/>

#### Data repositories
A data repository is, similar to a code repository, a named repository containing
data files, blobs and associated snapshots.

A repository name  

- consists of letters a-z, digits 0-9 and punctuation dash `-`
- starts and ends with a letter or digit
- all dashes `-` must be preceded and followed by letter or digit
- is between 3 and 63 characters in length

The data repository is a based on a single-level storage for simplicity, i.e. the
contents of a data repository is stored within the root level of the repository. 

The repository is the or highest or top-most level in Flow and txflow.

<br/>

#### Data file and blob specification 
The data file and blob specification is the initial metadata associated with a
data file or blob first commit to the repository as a point of reference.

```
{ 
  "version": "1.0.0",
  "type": "<content type>",
  "class": "<content class>",
  "reference": "<content reference>",
  "sha": "<SHA-1 of content>",
  "blobs": "<repository blob name>",
  "mime": "<content mime/file extension>",
  "name": "<content name>"
}
```

`version` represents the data file and blob specification schema version. It is 
reserved for future use allowing extended metadata, properties and attributes.
`version` only applies to the entry and not any specific REST API calls and 
features. _It does not represent the version of the data file or blob_. 

The content `type` is a keyword identifying the the type of data file or blob 
entry. The `type` is used for application and related business logic in 
processing or displaying the data file or blob.

The `type` is a case insensitive keyword consisting of the characters A-Z, digits
0-9, punctuation period `.` and underscores `_`. 

Supported types for Flow and txflow include the following

- `datafile` as a generic data file or blob
- `datafile.sas` as a data file in SAS data file format
- `datafile.rds` as a data file in R _RDS_ format
- `datafile.rda` as a data file in R _RData_ format
- `datafile.csv` as a data file in standard CSV format
- `datafile.xlsx` as a data file in Microsoft Excel format (xslx)
- `datafile.text` as a data file in plain text format

The `type` can also be specified with prefix (`<scope>:<type>`). 
The prefix provides a method to introduce a scope. If `type` is specified 
without a prefix, a global scope is assumed. Use the scope `custom` for
custom and bespoke types.

The `class` allows further classification of `type`. A `class` is a case
insensitive keyword consisting of the characters A-Z, digits
0-9, punctuation period `.` and underscores `_`. For example, the `class` _SDTM_
can denote that the data file or blob is an SDTM.

`reference` is a case insensitive keyword that can be used to assign a generic 
reference to the data file or blob. The principle is that data files or blobs 
of the same `type`, `class` and `reference` represent a group of like entries and
where each data file or blob is a particular instance of that. As an example, 
an entry of `type` of `datafile.rds`, `class` as `sdtm` and `reference` equal to
`ae` would represent being part of the _AE SDTMs in R RDS format_. 

The `sha` property is the data file or blobs SHA-1 digest. The value is derived
prior to storing the data file or blob in the configured storage.

The `blobs` attribute is the storage name of the data file or blob in the
configured storage. Both local and Azure Block Blob storage utilizes the data
file or blob SHA-1 digest for storage. Future implementations will support storing
large data files or blobs as multiple entries, hence `blobs` will include each 
stored entry.

The `mime` entry is captured and retained for reference.

The `name`entry represents the default identify of the data file or blob within
a snapshot. However, the snapshot can use a different name that is only applicable
within that specific snapshot.

<br/>


#### Snapshot specification
The snapshot specification defines the snapshot and represents a named collection
of data files and blobs to be included. A snapshot can only include data files
and blobs from the same repository where the snapshot is defined.

A snapshot can also be seen as a pre-defined view of data files and blobs within
a data repository.

```
{ 
  "version": "1.0.0",
  "name": "<content type>",
  "repository": "<content class>",
  "contents": [
     { 
        "version": "<data file or blob specification version>",
        "type": "<content type>",
        "class": "<content class>",
        "reference": "<content reference>",
        "sha": "<SHA-1 of content>",
        "blobs": "<repository blob name>",
        "mime": "<content mime/file extension>",
        "name": "<content name within the snapshot>"
     },
     ...
  ]
}
```

`version` in the main object represents the snapshot specification schema version. 
It is reserved for future use allowing extended metadata, properties and attributes
for the snapshot specification. `version` only applies to the snapshot specification
and not the schema version of `contents` entries or specific REST API calls and 
features. _It does not represent the version of the snapshot specification_. 

`name` is the snapshot name, case insensitive. The snapshot name  

- consists of letters a-z, digits 0-9 and punctuation dash `-` and underscore `_`
- starts and ends with a letter or digit
- all dashes `-` and underscores `_` must be preceded and followed by letter or digit
- is between 3 and 256 characters in length

Note that REST API requests related to a snapshot always includes references to 
the parent data repository, so the snapshot name does not require incorporating
the repository name or reference.

The `repository` is the name of the snapshot parent data repository. A snapshot 
can only be a member of a single repository.

`contents` is an array of snapshot members. All member properties and attributes
except the `name` entry are copies of the data file or blob specification. 

The default member `name` is the `name` property recorded within the data file and
blob specification, but the snapshot can use a different member `name` to enable a
snapshot to incorporate business process specific naming conventions while 
retaining a central default standard.

Note, the entry `version` property refers to the data file or blob specification 
version and is included as a reference for downstream processing controls and logic.


<br/>
<br/>

### API Reference


<br/>
<br/>


#### Authentication
The API uses Bearer tokens to authenticate a connection request using the standard header.

```
Authorization: Bearer <token>
```
See `cxapp::cxapp_authapi()` and the API Authentication section for the cxapp package 
for further details and configuration options.


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
in the configuration property `API.ADMINS`. If the requester is not an API admin, 
HTTP status code 403 with the message `Not permitted` is returned.

Default is to permit all requesters to create data repositories.

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
  "version": "1.0.0",
  "name": "<snapshot name>",
  "repository": "<repository>",
  "contents": [
    {
      "version": "<data file or blob specification version>",
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
The properties for the file or blob is defined within the context of the 
snapshot and may differ from those properties defined for snapshots where the same
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
example could be a repository entry with `type` equal to `datafile.sas`, `class` being
`sdtm` and the `reference` equal to `ae` to represent an AE SDTM in SAS data file format.

If `reference` is not specified, the value of `name` without the extension is used.

`mime` is a short reference to the content format. Default is the extension of `name`.

The returned record is in the format of a JSON object.

```
{
  "version": "<data file or blob specification version>",
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
other data file or blob properties are retained from the source `snapshot`.

The returned record is in the format of a JSON object.

```
{
  "version": "<data file or blob specification version>",
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

Drops an existing data file or blob from the specified work area. 

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
Commits the state of the current work area to the repository associated with the 
work area.

The option `snapshot` commits the work area to the specified snapshot. If the
specified snapshot does not exist in the repository, a new snapshot is created.

This option permits a work area to be initiated with an existing or new empty 
snapshot as a template and committing a new snapshot name.

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
      "txflow.work": "<work area parent directory>",
      "txflow.store": "<storage service>",
      "txflow.data": "<local file system: repository parent directory>",
      "azureblobs.url" : "<Azure block blob store: Azure store URL>"
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
  }, 
  "azure.oauth" : {
     "azure.oauth.url" : 
     "azure.oauth.clientid" :
     "azure.oauth.clientsecret" : "<set or unset>"
  }
}
```

The `configuration` properties and attributes for `repostories` is dependent 
on the storage configuration. The properties `txflow.data` and `azureblobs.url`
are only returned if local file system storage or Azure block blob storage,
respectively, is enabled.

If the Auditor service is disabled, the Auditor configuration may not be displayed.

If Azure OAuth is configured, the `azure.oauth` configuration properties and 
attributes are included. 


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



#### Azure Block Blob Storage
The following app properties are used for configuring storage to use Azure 
block blob store.

_Note that this storage method relies on access tokens obtained using Azure 
OAuth_.

Azure Blob Blob storage configuration is

- `TXFLOW.WORK` is the parent directory for work areas
- `TXFLOW.STORE` equal to `AZUREBLOBS`
- `AZUREBLOBS.URL` is the parent directory for data repositories


Azure OAuth configuration requires the following app properties

- `AZURE.OAUTH.URL` is the Microsoft Azure OAuth URL including the full 
  URL path that should include the tenant ID
- `AZURE.OAUTH.CLIENTID` the client ID associated with the storage account
- `AZURE.OAUTH.CLIENTSECRET` the client secret associated with the storage account

Note that `cxapp::cxapp_config()` supports environmental variables and secret/key
vaults for storing secrets. Please see Dependencies for further references to 
the R package cxapp.

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

<br/>


#### Auditor
txflow can use the Auditor service to store audit records that represents actions
and events occurring within txflow repositories and snapshots.

The Auditor is currently only available as a remote service and uses the following
configurtion options.

- `AUDITOR` to `enable` or `disable` the Auditor service integration
- `AUDITOR.ENVIRONMENT` identifies the txflow environment in audit records. If not 
  defined, the `nodename` as returned by `Sys.info()` is used.
- `AUDITOR.URL` is the URL (including port if non-standard) to the Auditor service
- `AUDITOR.TOKEN` is the Auditor access token associated with the txflow service.

Note that the Auditor configuration supports environmental variables and key/secret
vaults for storing the Auditor access token.

See `cxapp::cxapp_config()` for further details.


<br/>
<br/>
<br/>

## Examples
The first set of examples shared is using R.

But before we start, we need an access token to authenticate with for each request.

<br/>

#### Creating an Access Token
All requests, except a simple ping to the txflow service requires a token to 
authenticate each request.

The standard container image includes a local secrets vault that can be used for exploring the
service and a simple utility to generate a service token.

```
$ docker exec <container>  /opt/openapx/utilities/vault-apitoken-service.sh <name>
```

The example uses the `docker` utility assuming you are running the container image 
with something like Docker Desktop. If you are hosting the txflow service in a
cluster or some other utility, use the appropriate utility or tool.

The `vault-apitoken-service.sh` utility prints a token in clear text as output. 
This is the token value used for requests to use.

```
Token
----------------------------------------------------
an4wAtwXuPK0NVk3P7NdPftkaQWFN2UFewbyrqLd
```

The token identifies the requester, so any log entries will use `<name>`. The 
same applies if Auditor is enabled. The `<name>` is the actor, i.e. user or 
service, that is registered in the audit records as performing audited actions.

It is good practice that each service or user is given a unique token so that 
the requests can be easily identified.

<br/>

#### Using R with txflow
The following is a set of simple step-by-step examples that demonstrate how 
the txflow service works using plain R and the httr2 package.

To make the examples work, we define two standard objects, the first is the URL
(including the port number). txflow supports both HTTP (port 80) and HTTPS 
(port 443). Below, the non-standard port 81 is used as an example.

The second object is the access token.

```
url_to_auditor <- "http://auditor.example.com:81"
my_token_in_clear_text <- "<access token>"
```

Note that for HTTPS, the container contains a self-signed certificate that is
generated each time the container is built. If you are using HTTPS and the built-in
SSL certificates, ensure that you have disabled root certificate validation.

We will also need a few test files to upload. We will use some files with random 
content to represent a data blobs and a few of the classic R example data, such as
the data frames `mtcars` and `nottem` to represent R data files.

```
# -- random data
#    note: using the current working directory
#    note: create three files in the data directory 

for ( data_file in c( "test-data-01.txt", "test-data-02.txt", "test-data-03.txt") )
  base::writeLines( paste( sample( c( base::LETTERS, base::letters, as.character(0:9) ), 
                                   4000, 
                                   replace = TRUE ),
                           collapse = "" ), 
                    con = file.path( base::getwd(), "data", data_file ) )


# -- save mtcars and nottem a file
#    note: arbitrarily selected saveRDS() 

base::saveRDS( mtcars, , file = file.path( base::getwd(), "data", "mtcars.rds" ) )
base::saveRDS( nottem, , file = file.path( base::getwd(), "data", "nottem.rds" ) )
```

There should now be 3 random data blobs and 2 saved data frames in our data 
directory.


<br/>


##### Service Information
Information on the service and service configuration can easily be obtained.

```
# -- service information
#    GET /api/info

info <- httr2::request( url_to_auditor ) |>
  httr2::req_method("GET") |>
  httr2::req_url_path("/api/info") |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```  
  
The result is a list of named entries representing the configuration information.

<br/>


##### Create a Repository
A data repository is created in a single step.

```
# -- Create a named repository
#    PUT /api/repositories/<name>

repository <- "example-01"

create_repo <- httr2::request( url_to_auditor ) |>
  httr2::req_method("PUT") |>
  httr2::req_url_path("/api/repositories") |>
  httr2::req_url_path_append( repository ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```  

The new repository name is returned.

<br/>


##### Get a Snapshot Work Area
Snapshots are created, edited and saved using a snapshot work area.

To create a snapshot work area, simply request one. You can have multiple work
areas active at any one time and they do persist across sessions until they are
committed even though they are designed as a temporary staging area for performing
multiple steps before finally saving the result.

Note we are using the repository from the preceding example. A snapshot can only
exist within a repository.

```
# -- Get snapshot work area
#    GET /api/work/<repository>/<snapshot>

snapshot <- "mysnapshot-01"

work_area <- httr2::request( url_to_auditor ) |>
  httr2::req_method("GET") |>
  httr2::req_url_path("/api/work") |>
  httr2::req_url_path_append( repository ) |>
  httr2::req_url_path_append( snapshot ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()

work_area <- unlist(work_area)

```

A list containing the work area reference is returned. To make it easier, we unlist
the work area reference and save it in the `work_area` object that we will use
in below examples.


<br/>


##### Add files to a snapshot work area
One or more files can be added to the snapshot work area. The first file to be
added is what I would commonly refer to as a data blob.

```
# -- Add/Upload files to a work area
#    PUT /api/work/<work>/<reference>
#
#    note: the Content-type header must equal "application/octet-stream"

# note: using all default properties
# note: using the reference "mydatablob"

data_blob_file <- file.path( base::getwd(), "data", "test-data-01.txt" )

add_data_blob <- httr2::request( url_to_auditor ) |>
  httr2::req_method("PUT") |>
  httr2::req_url_path("/api/work") |>
  httr2::req_url_path_append( work_area ) |>
  httr2::req_url_path_append( "mydatablob" ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_headers( "Content-type" = "application/octet-stream" ) |>
  httr2::req_body_file( data_blob_file ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()

```

The returned object is the properties associated with the added/uploaded file. 
We can set these properties by specifying them as part of the request. In the 
example below, we set the properties `type`, `class`, `reference` and `mime`.


```
# -- Add/Upload files to a work area with properties
#    PUT /api/work/<work>/<name>?<attribites>
#
#    note: the Content-type header must equal "application/octet-stream"


# note: the reference is the file name derived using base::basename()
# note: setting the type to be "datafile.rds" noting it is an rds file
# note: setting the calss to be "examples" to give the type a bit more context
# note: setting reference equal to "nottem" 
# note: setting mime equal to "rds"

data_file <- file.path( base::getwd(), "data", "nottem.rds" )

add_data_file <- httr2::request( url_to_auditor ) |>
  httr2::req_method("PUT") |>
  httr2::req_url_path("/api/work") |>
  httr2::req_url_path_append( work_area ) |>
  httr2::req_url_path_append( base::basename( data_file ) ) |>
  httr2::req_url_query( "type" = "datafile.rds", 
                        "class" = "examples", 
                        "reference" = "nottem", 
                        "mime" = "rds"
                      ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_headers( "Content-type" = "application/octet-stream" ) |>
  httr2::req_body_file( data_file ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```

Again, the returned object is the properties associated with the added/uploaded 
file.


<br/>



##### Commit the work area to the repository
The snapshot work area needs to be committed to the repository before it becomes
available.

```
# -- Commit work area to the repository
#    PUT /api/commit/<work>

commit <- httr2::request( url_to_auditor ) |>
  httr2::req_method("PUT") |>
  httr2::req_url_path("/api/commit") |>
  httr2::req_url_path_append( work_area ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```

The returned object refers to the committed snapshot.


<br/>



##### Listing repositories and snapshots
The txflow REST API contains two simple endpoints for listing repositories and
snapshots.

```
# -- Get a list of repositories
#    GET /api/repositories

lst_repositories <- httr2::request( url_to_auditor ) |>
  httr2::req_method("GET") |>
  httr2::req_url_path("/api/repositories") |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```

The returned object from the above example is a list of repositories.

We can just as easily get a list of snapshots within a repository. Note we are
using the repository created at the beginning for our examples.

```
# -- Get a list of snapshots for a repository
#    GET /api/repositories/<repository>/snapshots

lst_snapshots <- httr2::request( url_to_auditor ) |>
  httr2::req_method("GET") |>
  httr2::req_url_path("/api/repositories") |>
  httr2::req_url_path_append( repository ) |>
  httr2::req_url_path_append( "snapshots" ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```

The returned object is a list of snapshots for our given repository. Note the 
format of the snapshot reference `<repository>/<snapshot>`, i.e. a snapshot
can only exist within a given repository.


<br/>



##### Get a repository snapshot specification
The specification for a given snapshot can be easily retrieved. Note that this 
does not download any snapshot data files or blobs.

```
# -- Get a repository snapshot specification
#    GET /api/repositories/<repository>/snapshots/<snapshot>

snapshot_spec <- httr2::request( url_to_auditor ) |>
  httr2::req_method("GET") |>
  httr2::req_url_path("/api/repositories") |>
  httr2::req_url_path_append( repository ) |>
  httr2::req_url_path_append( "snapshots" ) |>
  httr2::req_url_path_append( snapshot ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```

The returned object contains the specification of the snapshot.


<br/>



##### Retrieving/Downloading a data file or blob
There are several different approaches that can be used to retrieve or download
a data file or blob from the repository, either referring to the data file or 
blob directly (repository resource) or either as a named item or resource in the 
snapshot.

Using the previous example, we will download the first entry. The `snapshot_spec` 
is a nested list of named entries since we used `httr2::resp_body_json()` as
part of the request.

```
snapshot_first_entry <- snapshot_spec[["contents"]][[1]]

# - when retrieving by name
by_name <- snapshot_first_entry[["name"]]

# - when retrieving by resource
by_resource <- snapshot_first_entry[["blobs"]]
```

We can retrieve a data file or blob by its name within the snapshot.

```
# -- Get data file or blob by name in the snapshot 
#    GET /api/repositories/<repository>/snapshots/<snapshot>/<name>

output_file_by_name <- file.path( base::getwd(), by_name )

base::writeBin( httr2::request( url_to_auditor ) |>
                  httr2::req_method("GET") |>
                  httr2::req_url_path("/api/repositories") |>
                  httr2::req_url_path_append( repository ) |>
                  httr2::req_url_path_append( "snapshots" ) |>
                  httr2::req_url_path_append( snapshot ) |>
                  httr2::req_url_path_append( by_name ) |>
                  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
                  httr2::req_perform() |>
                  httr2::resp_body_raw(), 
                con = output_file_by_name )  
```

The retrieved file is saved to the path `output_file_by_name`.

We can also retrieve the same file by using the `blobs` reference within the 
snapshot entry.

```
# -- Get data file or blob by name in the snapshot 
#    GET /api/repositories/<repository>/snapshots/<snapshot>/<resource>

output_file_by_blob <- file.path( base::getwd(), by_resource )

base::writeBin( httr2::request( url_to_auditor ) |>
                  httr2::req_method("GET") |>
                  httr2::req_url_path("/api/repositories") |>
                  httr2::req_url_path_append( repository ) |>
                  httr2::req_url_path_append( "snapshots" ) |>
                  httr2::req_url_path_append( snapshot ) |>
                  httr2::req_url_path_append( by_resource ) |>
                  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
                  httr2::req_perform() |>
                  httr2::resp_body_raw(), 
                con = output_file_by_blob )  
```

Same result, but the output file name is now the blob name. Given that the output
file name is defined in `output_file_by_blob`. set it to what is reasonable as 
we only demonstrate the concept.

It is also possible to retrieve the data file or blob directly as a repository
resource and not through the snapshot. In this scenario, we use `by_resource` as
the name of the entry is only defined within a snapshot.

```
# -- Get data file or blob as a resource in the repository
#    GET /api/repositories/<repository>/<resource>

output_file_as_repository_resource <- file.path( base::getwd(), "repository_resource" )

base::writeBin( httr2::request( url_to_auditor ) |>
                  httr2::req_method("GET") |>
                  httr2::req_url_path("/api/repositories") |>
                  httr2::req_url_path_append( repository ) |>
                  httr2::req_url_path_append( by_resource ) |>
                  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
                  httr2::req_perform() |>
                  httr2::resp_body_raw(), 
                con = output_file_as_repository_resource )  

```

Note that in the examples above, we are writing the raw response body as a 
binary stream. In practice, there are two things to consider. The first is
verifying that the result was indeed the content and not an error. In the code
above, we blindly trust that the retrieval was successful.

The second is regarding large files. With this httr2 example, the entire file 
content is processed through memory. A more optimal approach should be used 
for retrieving large files.

<br/>


##### Edit a repository snapshot
Editing a snapshot is just as straightforward. 

In our example, we will create a new snapshot using the previous snapshot as
a template. We are also introducing the possibility to drop a data file or blob
in the snapshot specification. Note, that dropping a data file or blob from a
snapshot does not delete it from the repository.

```
# -- Get snapshot work area using existing snapshot
#    GET /api/work/<repository>/<snapshot>

edit_work_area <- httr2::request( url_to_auditor ) |>
  httr2::req_method("GET") |>
  httr2::req_url_path("/api/work") |>
  httr2::req_url_path_append( repository ) |>
  httr2::req_url_path_append( snapshot ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()

edit_work_area <- unlist(edit_work_area)
```

We then drop the named item `mydatablob` from the work area snapshot.

```
# -- Drop named item 
#    DELETE /api/work/<work>/<name>

drop_blob <- httr2::request( url_to_auditor ) |>
  httr2::req_method("DELETE") |>
  httr2::req_url_path("/api/work") |>
  httr2::req_url_path_append( edit_work_area ) |>
  httr2::req_url_path_append( "mydatablob" ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```

And for good measure, let us add the data file or blob `mtcars.rds` following 
our previous examples.

```
# -- Add/Upload files to a work area with properties
#    PUT /api/work/<work>/<name>?<attribites>
#
#    note: the Content-type header must equal "application/octet-stream"


cars_data_file <- file.path( base::getwd(), "data", "mtcars.rds" )

cars_add_data_file <- httr2::request( url_to_auditor ) |>
  httr2::req_method("PUT") |>
  httr2::req_url_path("/api/work") |>
  httr2::req_url_path_append( edit_work_area ) |>
  httr2::req_url_path_append( base::basename( cars_data_file ) ) |>
  httr2::req_url_query( "type" = "datafile.rds", 
                        "class" = "examples", 
                        "reference" = "mtcars", 
                        "mime" = "rds"
  ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_headers( "Content-type" = "application/octet-stream" ) |>
  httr2::req_body_file( cars_data_file ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```

At this point, we commit the work area but using the new snapshot name
`mysnapshot-02`.

```
# -- Commit edited work area to the repository
#    PUT /api/commit/<work>

commit_edits <- httr2::request( url_to_auditor ) |>
  httr2::req_method("PUT") |>
  httr2::req_url_path("/api/commit") |>
  httr2::req_url_path_append( edit_work_area ) |>
  httr2::req_url_query( "snapshot" = "mysnapshot-02" ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```

Listing the snapshots in the repository includes our new snapshot.

```
# -- Get a list of snapshots for a repository
#    GET /api/repositories/<repository>/snapshots

lst_snapshots <- httr2::request( url_to_auditor ) |>
  httr2::req_method("GET") |>
  httr2::req_url_path("/api/repositories") |>
  httr2::req_url_path_append( repository ) |>
  httr2::req_url_path_append( "snapshots" ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```

We can also verify that the edits to the snapshot were saved by retrieving the 
new snapshot specification.

```
# -- Get a repository snapshot specification
#    GET /api/repositories/<repository>/snapshots/<snapshot>

edited_snapshot_spec <- httr2::request( url_to_auditor ) |>
  httr2::req_method("GET") |>
  httr2::req_url_path("/api/repositories") |>
  httr2::req_url_path_append( repository ) |>
  httr2::req_url_path_append( "snapshots" ) |>
  httr2::req_url_path_append( "mysnapshot-02" ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```

<br/>


##### Adding data file or blob from another repository snapshot
The examples so far has always added or uploaded a file to include. We can 
just as easily add a file as a reference from another snapshot. 

We will use the preceding example as a basis, starting out with `mysnapshot-01` 
and adding the named item `mtcars` from `mysnapshot-02`, but now giving it 
the name `cars`. 

Let us start with setting up a work area.

```
# -- Get snapshot work area using existing snapshot
#    GET /api/work/<repository>/<snapshot>

edit_work_area2 <- httr2::request( url_to_auditor ) |>
  httr2::req_method("GET") |>
  httr2::req_url_path("/api/work") |>
  httr2::req_url_path_append( repository ) |>
  httr2::req_url_path_append( snapshot ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()

edit_work_area2 <- unlist(edit_work_area2)
```

The next step is to add `mtcars` from `mysnapshot-02` and give it 
the name `cars`. 

```
# -- Add data file or blob from a previous snapshot by name
#    PATCH /api/work/<work>/<reference>?snapshot=<snapshot>&name=<name>

add_existing <- httr2::request( url_to_auditor ) |>
  httr2::req_method("PATCH") |>
  httr2::req_url_path("/api/work") |>
  httr2::req_url_path_append( edit_work_area2 ) |>
  httr2::req_url_path_append( "mtcars" ) |>
  httr2::req_url_query( "snapshot" = "mysnapshot-02", 
                        "name" = "cars" ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```

Let us commit this update to a new snapshot `mysnapshot-03` and look at the 
results.

```
# -- Commit edited work area to the repository
#    PUT /api/commit/<work>

commit_edits2 <- httr2::request( url_to_auditor ) |>
  httr2::req_method("PUT") |>
  httr2::req_url_path("/api/commit") |>
  httr2::req_url_path_append( edit_work_area2 ) |>
  httr2::req_url_query( "snapshot" = "mysnapshot-03" ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()


# -- Get a repository snapshot specification
#    GET /api/repositories/<repository>/snapshots/<snapshot>

amended_snapshot_spec <- httr2::request( url_to_auditor ) |>
  httr2::req_method("GET") |>
  httr2::req_url_path("/api/repositories") |>
  httr2::req_url_path_append( repository ) |>
  httr2::req_url_path_append( "snapshots" ) |>
  httr2::req_url_path_append( "mysnapshot-03" ) |>
  httr2::req_auth_bearer_token( my_token_in_clear_text ) |>
  httr2::req_perform() |>
  httr2::resp_body_json()
```

The snapshot specification `mysnapshot-03` now contains the three data files and
blob `mtcars`, `nottem` and `mydatablob`.



















