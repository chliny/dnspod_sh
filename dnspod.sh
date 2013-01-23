#########################################################################
# File Name: dnspod.sh
# Author: chliny
# mail: chliny11@gmail.com
# Created Time: 2012年11月22日 星期四 10时35分59秒
#########################################################################
#!/bin/bash
email="登录邮箱"
password="登录密码"
format="json"
lang="en"
apiurl="https://dnsapi.cn/"
commonPost="login_email=$email&login_password=$password&format=$format&lang=$lang"
# 域名列表，格式"子域名/主机记录 主域名"
domainGroup[0]="subdomain1 masterdomain1.com"
domainGroup[1]="subdomain2 masterdomain2.com"

# 获取本地ip
getNewIp()
{
    ifconfig eth0 | grep inet | grep -v inet6 | grep -v 127.0.0.1 | awk '{print $2}'
}

# 通过key得到找到JSONdomain字段中key对应的值
# $1 JSON
# $2 key
getDomainDataByKey()
{
    if [ "$2" == "id" ];then
        echo $1 | grep -E -o "\"domain[^}]*}" | grep -E -o "\"$2[^\,]*\," | grep -E -o ":[^\,]*" | cut -c 2-
    else 
        echo $1 | grep -E -o "\"domain[^}]*}" | grep -E -o "\"$2[^\,]*\," | grep -E -o ":\"[^\"]*" | cut -c 3-
    fi
}

# 通过key得到找到JSONrecord字段中key对应的值
# record字段在getRecordList()中有做过处理
# $1 JSON
# $2 key
getRecordDataByKey()
{
    echo $1 | grep -E -o "\"$2[^\,]*\," | grep -E -o ":\"[^\"]*" | cut -c 3-
}

# 根据域名id获取记录列表并做一定处理
# $1 域名id
# $2 子域名/主机记录
getRecordList()
{
    allRecord=`curl -d $commonPost"&domain_id=$1&offset=0&length=20&sub_domain=$2" $apiurl"Record.List"`
    echo $allRecord | grep -E -o "records.*" | grep -E -o "\{[^{}]*\}" | grep -E -v "dnspod\.net"
}

# 获取域名列表
getDomainList()
{
	curl -d $commonPost"&type=mine&offset=0&length=10"  $apiurl"Domain.List"
}

# 修改记录
changeIp()
{
    arrnum=${#domainGroup[@]}
    for (( i=0;i<arrnum;++i));do
        sub_domain=`echo ${domainGroup[$i]} | awk '{print $1}'`
        master_domain=`echo ${domainGroup[$i]} | awk '{print $2}'`

        domainListInfo=$(getDomainList)
        domainid=$(getDomainDataByKey "$domainListInfo" 'id')
        recordList=$(getRecordList $domainid "$sub_domain")

        oldip=$(getRecordDataByKey "$recordList" 'value')
        newip=$(getNewIp)
        # 新ip与旧ip不相等则进行修改
        if [ "$newip" != "$oldip" ];then
            recordid=$(getRecordDataByKey "$recordList" 'id')
            recordName=$(getRecordDataByKey "$recordList" 'name')
            recordTtl=$(getRecordDataByKey "$recordList" 'ttl')
            recordType=$(getRecordDataByKey "$recordList" 'type')
            recordLine='默认'

            # 判断取值是否正常，如果值为空就不处理
            if [ -n "$recordid" ] && [ -n "$recordTtl" ] && [ -n "$recordType" ]; then
                changedRecords="&domain_id=$domainid&record_id=$recordid&sub_domain=$sub_domain&record_type=$recordType&record_line=$recordLine&ttl=$recordTtl&value=$newip"
                curl -d $commonPost$changedRecords $apiurl"Record.Modify"
            fi
        fi
    done
}

changeIp
