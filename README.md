# elasticsearch_housekeep
This is a simple PowerShell script to do housekeeping on ElasticSearch indices, removing older documents to manage disk space

## Why did I make this?
ElasticSearch is an awesome document store. In fact, I completely replaced SQL with ElasticSearch for some of my applications that only need static queries and no relational manipulations. It is extremely efficient, and fast for most practical purposes. Unfortunately, this also means that log or document maintenance is often ignored, and disk space is normally not monitored until it runs out. This script is intended to avoid this issue, making sure older documents that are no longer needed are purged from the data store.

## Usage
1. Define ElasticSearch API username in variable `$username`
2. Define ElasticSearch API password in variable `$password`
3. Populate the `$EShost` array variable with ElasticSearch hosts that expose the API layer
4. Define the indices, document types, and age threshold in hashtable variable `$indexCol`
5. Define the timestamp attribute to check in variable `$ES_timestamp`
6. Set up the script to run on a schedule to perform automated cleanup
