#' A R-Package for accessing Openspending
#'
#' Openspending is a global spending data analysis and visualization
#' plattform it offers a JSON based API to access various information of 
#' the stored data. \code{r-openspending} helps accessing openspending data
#' from within R
#'
#' @import RCurl rjson
#' @aliases openspending ropenspending
#' @name ropenspending-package
#' @keywords openspending
#' @docType package
#' @example examples/openspending.aggregate.R
#' @author Michael Bauer \email{michael.bauer@@okfn.org}
library("RCurl")
library("rjson")

openspending.host="http://openspending.org"
openspending.api=paste(openspending.host,"/api/2/",sep="")

#' openspending.datasets 
#'
#' Accesses all Openspending Datasets
#'
#' @name openspending.datasets
#' @param territory (Optional): searches for datasets in a specific country (2 letter ISO codes)
#' @param language (Optional): searches for datasets in a specifig langue (2 letter code)
#' @example examples/openspending.datasets.R
#' @export
openspending.datasets <- function(territory=NA,language=NA) {
  url=paste(openspending.host,"/datasets.json?",sep="")
  if (!is.na(territory)) {
    url=paste(url,"&territories=",territory,sep="")
    }
  if (!is.na(language)) {
    url=paste(url,"&languages=",language,sep="")
    }
  j=getURL(url)
  data=fromJSON(j)
  return(data$datasets)
  }

#' Openspending Dimensions
#'
#' Gives information about the dimensions used in a Dataset (the parameters
#' you could use to cut or drilldown your analysis)
#'
#' @name openspending.dimensions
#' @param dataset the dataset you want to have information on
#' @example examples/openspending.dimensions.R
#' @export
openspending.dimensions <- function(dataset) {
  url=paste(openspending.host,dataset,"dimensions.json",sep="/")
  j=getURL(url)
  return(fromJSON(j))
  }

#' Openspending Distinct
#'
#' get the distinct (unique) values in a dimension
#'
#' @name openspending.distinct
#' @param dataset the dataset to work on
#' @param dimension the dimension you want distinct values from
#' @example examples/openspending.distinct.R
#' @export
openspending.distinct <- function(dataset,dimension) {
  url=paste(openspending.host,dataset,paste(dimension,"distinct.json",sep="."),sep="/")
  j=getURL(url)
  return(as.vector(fromJSON(j)$results))
  }

#' Openspending Model
#'
#' Shows you the internal model of the dataset in Openspending - what
#' columns do exist and how are they mapped to the source file
#' @name openspending.model
#' @param dataset the dataset you want to see the model of
#' @example examples/openspending.model.R
#' @export
openspending.model <- function(dataset) {
  url=paste(openspending.host,dataset,"model.json",sep="/")
  j=getURL(url)
  return(fromJSON(j))
  }

#' Openspending Aggregate
#' 
#' Uses the Aggregate API to get data out of a dataset on OpenSpending and
#' perform basic analysis
#' @name openspending.aggregate
#' @param dataset the dataset you want to work on
#' @param cut (optional) the cut (filter) you want to apply to the dataset
#' e.g. \code{time.year:2012}, can be a vector of multiple conditions
#' @param drilldown (optional) the drilldown you want to do - how you want the data
#' aggregated - need to be dimension names, can be a vector for multiple
#' level drilldown
#' @param measure (default=amount) the measurement you want to have
#' aggregated. Defaults to amount since this is the measure that has to
#' exist in all datasets.
#' @param order (optional) parameters to order by. e.g. \code{amount:asc},
#' can be a vector
#' @example examples/openspending.aggregate.R
#' @export
openspending.aggregate <- function(dataset, cut=NA, drilldown=NA, measure="amount",order=NA) {
  url=paste(openspending.api,"aggregate?dataset=",dataset,"&measure=",measure,sep="")
  if (!is.na(cut[1])) {
    url=paste(url,"&cut=",paste(cut,collapse="|"),sep="")
    }
  if (!is.na(drilldown[1])) {
    url=paste(url,"&drilldown=",paste(drilldown,collapse="|"),sep="")
    };
  if(!is.na(order[1])) {
    url=paste(url,"&order=",paste(order,collapse="|"),sep="")
    };
  j=getURL(url)
  data=fromJSON(j)
  if (!is.null(data$errors)) {
    write(data$errors,stderr())
    return(NULL)
    }
  return(data)
  }

openspending._getChildren <- function (drilldown,data,measure="amount",p=T) {
  if (p && exists("mclapply") ) {
      t.lapply<-mclapply
      }
  else {
    t.lapply=lapply
    }
  if (is.na(drilldown[1])) {
    return (list())
    }
  if (length(drilldown)==1) {
    dd=drilldown[1]
    drilldown=NA
    }
  else {  
    dd=drilldown[1]
    drilldown=drilldown[seq(2,length(drilldown))]
    }
  getLabel <- function(x) {
    if (is.list(x[[dd]])) {
        return (x[[dd]]$label)
      }
      else {
        return (x[[dd]])
        }
    }
   names=as.vector(sapply(data,getLabel))
   if (is.na(drilldown[1])) {
    return (lapply(unique(names),function(x) {
      o=data[names==x][[1]];
      return(
        list(name=x, dimension=dd, amount=o[[measure]])
        )
      }
      ))
    }
   else {
    return(t.lapply(unique(names),function(x) {
      children=openspending._getChildren(drilldown,data[names==x],measure,p=F);
      amount=sum(as.vector(sapply(children,function(x) { return(x$amount)
      })));
      return (list(name=x, dimension=dd, amount=amount, children=children))
      }))
    }
  }
#' Openspending aggregateTree
#'
#' Similar to \code{openspending.aggregate} but returns the results in a
#' tree structure.
#' @name openspending.aggregateTree
#' @inheritParams openspending.aggregate
#' @param p (default=T) whether or not R should attempt to use parallel to
#' parallelize building the tree - turn this off if you run out of memory
#' or have other issues
#' @example examples/openspending.aggregateTree.R
#' @export
openspending.aggregateTree <- function(dataset, cut=NA, drilldown=NA, measure="amount", order=NA, p=T) {
  if (p) {
    require("parallel")
    }
  data=openspending.aggregate(dataset,cut=cut,drilldown=drilldown,measure=measure,order=order)
  root=list(amount=data$summary$amount,currency=data$summary$currency,children=openspending._getChildren(drilldown,data$drilldown,measure,p))
  return(root);
  }

#' Openspending list.to.data.frame
#'
#' Converts an evenly structured list to a dataframe - the first level of
#' lists will be interpreted as the rows
#'
#' @name openspending.list.to.data.frame
#' @param lst the list to be converted to a dataframe
#' @example examples/openspending.datasets.R
#' @export

openspending.list.to.data.frame <- function(lst) {
  results=list()
  d=lst[[1]]
  for (i in names(d)) {
    if (is.list(d[[i]])) {
      print(paste("list:",i))
      if (!is.null(names(d[[i]]))) {
        for (j in names(d[[i]])) {
          results[[paste(i,j,sep=".")]]=as.vector(
              sapply(lst,function(x) {
                return(x[[i]][[j]]) }));
          }
          }
          else {
            results[[i]]=as.vector(sapply(lst,
              function(x) { return (paste(x[[i]],collapse=", "))}))}
        
    }
    else {
      results[[i]]=as.vector(sapply(lst,function(x) {if (is.null(x[[i]])) {
        return ("")}
        else { 
          if (length(x[[i]])>1) {
            return ( paste(x[[i]],collapse=", "))}
          else {
            return (x[[i]])
            }}}))
      }
  }
  print(results)
  return(data.frame(results));    
  }

#' Openspending as.data.frame
#'
#' converts the output from \code{openspending.aggregate} into a data.frame
#'
#' @name openspending.as.data.frame
#' @param data the output from openspending.aggregate
#' @example examples/openspending.aggregate.R
#' @export
openspending.as.data.frame <- function(data) {
  results=openspending.list.to.data.frame(data$drilldown);
  results[["currency"]]=c(data$summary$currency$amount);
  return(data.frame(results));    
}  

#' Openspending search
#' 
#' uses the openspending search API to search for specific records in a
#' dataset
#'
#' @name openspending.search
#' @param q (optional) the query string
#' @param dataset (optional) the dataset to be searched
#' @param filter (optional) a field to filter for
#' @param category (optional) filter for category (budget, spending or other)
#' @example examples/openspending.search.R
#' @export
openspending.search <- function(q=NA, dataset=NA, filter=NA, category=NA) {
  url=paste(openspending.api,"search?",sep="")
  params=c()
  if (!is.na(q)) {
    params=c(params,paste("q",q,sep="="))
    }
  if (!is.na(dataset)) {
    params=c(params,paste("dataset",dataset,sep="="))
    }
  if (!is.na(filter[1])) {
    params=c(params,paste("filter",paste(filter,collapse="|"),sep="="))
    }
  if (!is.na(category)) {
    params=c(params,paste("category",category,sep="="))
    }
  url=paste(url,paste(params,collapse="&"),sep="")
  j=getURL(url)
  data=fromJSON(j)
  return(data)
}
