import boto3
from datetime import datetime
import re

def filter_environments_from_cloudformation(cloudformation):
    pattern_prefix = "ecs-"
    pattern_suffix = "-[a-zA-Z]{3}\d$"
    pattern = re.compile(f"^{pattern_prefix}[a-zA-Z]{{6}}{pattern_suffix}")

    env = []
    #pattern=r"^ecs-[a-zA-Z]{6}-pd$"
    response = cloudformation.list_stacks()
    for i in range(len(response["StackSummaries"])):
        if re.search(pattern, response["StackSummaries"][i]["StackName"]):
            #print(response["StackSummaries"][i]["StackName"])
            env.append(response["StackSummaries"][i]["StackName"][-4:])
            #print(client_id)
    return env



def filter_client_id_cloudformation(cloudformation,data):
    pattern_prefix = "ecs-"
    pattern_suffix = "-" + data["env"]
    pattern = re.compile(f"^{pattern_prefix}[a-zA-Z]{{6}}{pattern_suffix}$")
    pattern_for_getting_cleintid = re.compile(f"^{pattern_prefix}|{pattern_suffix}$")

    #pattern=r"^ecs-[a-zA-Z]{6}-pd$"
    response = cloudformation.list_stacks()
    for i in range(len(response["StackSummaries"])):
        if re.search(pattern, response["StackSummaries"][i]["StackName"]):
            client_id = re.sub(pattern_for_getting_cleintid, "", response["StackSummaries"][i]["StackName"])
    return client_id



def get_time_period():
    now = datetime.now().time()
    if  5 < now.hour < 18 :
        return "morning"
    # elif 12 <= now.hour < 18:
    #     return "afternoon"
    # elif 18 <= now.hour < 22:
    #     return "evening"
    else:
        return "night"



def get_paramters_from_cloudformation(cloudformation,data):

    stack_name = "ecs-" + data["client_id"] + "-" + data["env"]
    cluster_name = data["client_id"] + "-" + data["env"] + "-ecs"
    data["cluster-name"] = cluster_name
    #print(stack_name)
    response = cloudformation.describe_stacks(StackName=stack_name)
    stack = response['Stacks'][0]
    parameters = stack['Parameters']

    # Print the parameter names and values
    # print(f"Parameters for stack '{cloudformation_name}':")
    # for parameter in parameters:
    #     name = parameter['ParameterKey']
    #     value = parameter['ParameterValue']
    #     print(f"{name}: {value}")

    for parameter in parameters:
        name = parameter['ParameterKey']
        value = parameter['ParameterValue']
        if name == 'TomcatBatchServiceMaxCapacity':
            TomcatBatchServiceMaxCapacity = value
            data["TomcatBatchServiceMaxCapacity"] = value
        if name == 'TomcatServiceMaxCapacity':
            TomcatServiceMaxCapacity = value
            data["TomcatServiceMaxCapacity"] = value
        if name == 'FilebeatServiceMinCapacity':
            TomcatServiceMaxCapacity = value
            data["FilebeatServiceMinCapacity"] = value

    return data

def update_ecs_service(ecs,data):
    if data["currentTimeschedule"]=="night":
        ecs.update_service(cluster=data["cluster-name"],service=data["service-name"],desiredCount=int(data["nightContainerCount"]))
        ecs.update_service(cluster=data["cluster-name"],service=data["service-name-2"],desiredCount=int(data["nightContainerCount"]))
        print("Descaled cluster", data["cluster-name"] , "service " , data["service-name"] ," Container to count", data["nightContainerCount"])
        print("Descaled cluster", data["cluster-name"] , "service " , data["service-name-2"] ," Container to count", data["nightContainerCount"])

    else:
        ecs.update_service(cluster=data["cluster-name"],service=data["service-name"],desiredCount=int(data["TomcatBatchServiceMaxCapacity"]))
        ecs.update_service(cluster=data["cluster-name"],service=data["service-name-2"],desiredCount=int(data["FilebeatServiceMinCapacity"]))
        print("Scaled cluster", data["cluster-name"] , "service " , data["service-name"] ," Container to count", data["TomcatBatchServiceMaxCapacity"])
        print("Scaled cluster", data["cluster-name"] , "service " , data["service-name-2"] ," Container to count", data["FilebeatServiceMinCapacity"])

def update_cloudwatch_alarm(cloudwatch,data):
    cloudwatch_alarm_list_dict = cloudwatch.describe_alarms()
    alarm_list = []
    # Print the list of alarms
    for alarm in cloudwatch_alarm_list_dict['MetricAlarms']:
        if data["cluster-name"] + "/" + "tomcat-batch-service-AlarmHigh" in alarm['AlarmName']:
            alarm_list.append(alarm['AlarmName'])
            #print(alarm_list)
            alarms = cloudwatch.describe_alarms(AlarmNames=alarm_list)
            for i in range(len(alarm_list)):
                if alarms["MetricAlarms"][i]["MetricName"] == "MemoryUtilization":
                    #print(alarm_list[i])
                    #print(alarms["MetricAlarms"][i]["EvaluationPeriods"])
                    #print(alarms["MetricAlarms"][i]["ComparisonOperator"])
                    if data["currentTimeschedule"] == "night":
                        cloudwatch.put_metric_alarm(AlarmName=alarm_list[i], MetricName=alarms["MetricAlarms"][i]["MetricName"], Threshold=data["nightAlarmthreshold"],Period=alarms["MetricAlarms"][i]["Period"],Statistic=alarms["MetricAlarms"][i]["Statistic"],Namespace=alarms["MetricAlarms"][i]["Namespace"], EvaluationPeriods=alarms["MetricAlarms"][i]["EvaluationPeriods"],ComparisonOperator=alarms["MetricAlarms"][i]["ComparisonOperator"])
                        print("Updated the Threshold for alarm:",alarm_list[i]," to ",data["nightAlarmthreshold"])
                    else:
                        cloudwatch.put_metric_alarm(AlarmName=alarm_list[i], MetricName=alarms["MetricAlarms"][i]["MetricName"], Threshold=data["MorningAlarmThreashold"],Period=alarms["MetricAlarms"][i]["Period"],Statistic=alarms["MetricAlarms"][i]["Statistic"],Namespace=alarms["MetricAlarms"][i]["Namespace"], EvaluationPeriods=alarms["MetricAlarms"][i]["EvaluationPeriods"],ComparisonOperator=alarms["MetricAlarms"][i]["ComparisonOperator"])
                        print("Updated the Threshold for alarm:",alarm_list[i]," to ",data["MorningAlarmThreashold"])



if __name__ == "__main__":
    # Set the profile name
    data = {"nightContainerCount":0,"env": "" ,"service-name" : "tomcat-batch-service","service-name-2":"filebeat-service","nightAlarmthreshold":130,"MorningAlarmThreashold":100}
    profile_name = 'default'
    region_name = 'us-east-2'
    session = boto3.Session(profile_name=profile_name)
    service_name = 'tomcat-batch-service'
    cluster_name = 'arlitx-env1-ecs'
    # Get ECS cluster and its attributes
    ecs = session.client('ecs',region_name=region_name)
    cloudformation = boto3.client('cloudformation',region_name=region_name)
    cloudwatch = boto3.client('cloudwatch',region_name=region_name)
    # Add prod incase you need to do scaling for prod
    env = []
    env.extend(filter_environments_from_cloudformation(cloudformation))
    for env_id in range(len(env)):
        data["env"]=env[env_id]
        data["client_id"]=filter_client_id_cloudformation(cloudformation,data)
        data.update(get_paramters_from_cloudformation(cloudformation,data))
        data['currentTimeschedule']=get_time_period()
        print("\n-- Executing Scaling Event for ECS Cluster", data["cluster-name"], "on :",datetime.now().date(), " at ",data["currentTimeschedule"]," at ", datetime.now().time().strftime("%H:%M:%S.%f")[:8],"----------------\n ")
        update_ecs_service(ecs,data)
        update_cloudwatch_alarm(cloudwatch,data)
        print("\n",data)
        #print(env)