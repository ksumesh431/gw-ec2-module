import boto3
from datetime import datetime
import re

def filter_environments_from_cloudformation(cloudformation):
    pattern_prefix = "ecs-"
    pattern_suffix = "-[a-zA-Z]{3}\d$"    pattern = re.compile(f"^{pattern_prefix}[a-zA-Z]{{6}}{pattern_suffix}")

    env = []
    #pattern=r"^ecs-[a-zA-Z]{6}-pd$"    response = cloudformation.list_stacks()
    for i in range(len(response["StackSummaries"])):
        if re.search(pattern, response["StackSummaries"][i]["StackName"]):
            #print(response["StackSummaries"][i]["StackName"])
            env.append(response["StackSummaries"][i]["StackName"][-4:])
            #print(client_id)
    return env

def get_time_period():
    now = datetime.now().time()
    #print(now.hour)
    if 5 < now.hour < 18:
        return "morning"
#    elif 12 <= now.hour < 18:
#        return "afternoon"
#    elif 18 <= now.hour < 22:
#        return "evening"
    else:
        return "night"

def filter_client_id_cloudformation(cloudformation,data):
    pattern_prefix = "ecs-"
    pattern_suffix = "-" + data["env"]
    pattern = re.compile(f"^{pattern_prefix}[a-zA-Z]{{6}}{pattern_suffix}$")
    pattern_for_getting_cleintid = re.compile(f"^{pattern_prefix}|{pattern_suffix}$")

    #pattern=r"^ecs-[a-zA-Z]{6}-pd$"
    response = cloudformation.list_stacks()
    for i in range(len(response["StackSummaries"])):
        if re.search(pattern, response["StackSummaries"][i]["StackName"]):
            #print(response["StackSummaries"][i]["StackName"])
            client_id = re.sub(pattern_for_getting_cleintid, "", response["StackSummaries"][i]["StackName"])
            #print(client_id)
    return client_id

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
        if name == 'ClusterSize':
            TomcatBatchServiceMaxCapacity = value
            data["ClusterSizeDesired"] = value
        if name == 'ClusterSizeMax':
            TomcatServiceMaxCapacity = value
            data["ClusterSizeMax"] = value
    return data


def get_autoscaling_group_name_from_cloudformation(cloudformation,client_id):

    pattern_prefix = "ecs-"
    pattern_suffix = "-" + data["env"] + "-ECSClusterStack-"
    pattern = re.compile(f"^{pattern_prefix}[a-zA-Z]{{6}}{pattern_suffix}")
    #print(pattern)
    #pattern=r"^ecs-[a-zA-Z]{6}-pd-ECSClusterStack-"
    response = cloudformation.list_stacks()
    for i in range(len(response["StackSummaries"])):
        if re.search(pattern, response["StackSummaries"][i]["StackName"]):
            #print(response["StackSummaries"][i]["StackName"])
            AS_group_stack_name = response["StackSummaries"][i]["StackName"]


    AS_group_output = cloudformation.describe_stacks(StackName=AS_group_stack_name)
    if "Outputs" in AS_group_output["Stacks"][0]:
        outputs = AS_group_output["Stacks"][0]["Outputs"]
        for output in outputs:
            if output['OutputKey'] == "ECSAutoScalingGroupName":
                #print(f"{output['OutputKey']}: {output['OutputValue']}")
                AS_group_name = output['OutputValue']
    else:
        print("No stack outputs found.")
    return AS_group_name


def get_autoscaling_group_instance_count(autoscaling,AS_group_name):
    AS_data = {}
    AS_group_conf_dict = autoscaling.describe_auto_scaling_groups(AutoScalingGroupNames=[AS_group_name])
    AS_data["AS_Min_instance_count"] = AS_group_conf_dict["AutoScalingGroups"][0]["MinSize"]
    AS_data["AS_Max_instance_count"] = AS_group_conf_dict["AutoScalingGroups"][0]["MaxSize"]
    AS_data["AS_desired_instance_count"] =   AS_group_conf_dict["AutoScalingGroups"][0]["DesiredCapacity"]
    return AS_data

def update_autoscaling_group(autoscaling,data):
    if data["CurrentTime"] == "night" and data["AS_Max_instance_count"] >= data["NightInstanceCount"]:
        autoscaling.update_auto_scaling_group(AutoScalingGroupName=data["AS_group_name"],DesiredCapacity=data["NightInstanceCount"],MinSize=data["NightInstanceCount"])
        print("Auto Scaling Group",data["AS_group_name"],"descaled to count: ",data["NightInstanceCount"])
    elif data["CurrentTime"] == "night" and int(data["AS_Max_instance_count"]) < int(data["NightInstanceCount"]):
        autoscaling.update_auto_scaling_group(AutoScalingGroupName=data["AS_group_name"],DesiredCapacity=int(data["NightInstanceCount"]),MaxSize=int(data["NightInstanceCount"]),MinSize=int(data["NightInstanceCount"]))
        print("Auto Scaling Group",data["AS_group_name"],"descaled to count: ",data["NightInstanceCount"]," and Max count was updated to ",data["NightInstanceCount"] )
    elif data["CurrentTime"] == "morning" and int(data["AS_Max_instance_count"]) < int(data["ClusterSizeDesired"]):
        autoscaling.update_auto_scaling_group(AutoScalingGroupName=data["AS_group_name"],DesiredCapacity=int(data["ClusterSizeDesired"]),MaxSize=int(data["ClusterSizeMax"]),MinSize=int(data["ClusterSizeDesired"]))
        print("Auto Scaling Group",data["AS_group_name"],"scaled to count: ",data["NightInstanceCount"]," and Max count was updated to ",data["ClusterSizeDesired"] )
    else:
        autoscaling.update_auto_scaling_group(AutoScalingGroupName=data["AS_group_name"],DesiredCapacity=int(data["ClusterSizeDesired"]),MinSize=int(data["ClusterSizeDesired"]))
        print("Auto Scaling Group",data["AS_group_name"],"scaled to count: ",data["ClusterSizeDesired"])


if __name__ == "__main__":
    # # Set the profile names
    # data = {"MorningContainerCount":1,"nightContainerCount":0}
    # cloudformation_name='ecs-arlitx-env1'
    data = {"NightInstanceCount" : 0 ,"env": "env1"}
    profile_name = "default"
    region_name = 'us-east-2'
    session = boto3.Session(profile_name=profile_name)


    #BOTO 3 AWS service Client Code block
    cloudformation = boto3.client('cloudformation',region_name=region_name)
    autoscaling = boto3.client('autoscaling',region_name=region_name)

    # Add prod incase you need to do scaling for prod
    env = []
    env.extend(filter_environments_from_cloudformation(cloudformation))
    for env_id in range(len(env)):
        data["env"]=env[env_id]
        data["client_id"]=filter_client_id_cloudformation(cloudformation,data)
        get_autoscaling_group_name_from_cloudformation(cloudformation,data["client_id"])
        data.update(get_paramters_from_cloudformation(cloudformation,data))
        data["AS_group_name"] = get_autoscaling_group_name_from_cloudformation(cloudformation,data["client_id"])
        data.update(get_autoscaling_group_instance_count(autoscaling,data["AS_group_name"]))
        data["CurrentTime"]=get_time_period()
        print("\n-- Executing Scaling Event for Auto Scaling Group", data["AS_group_name"], "on :",datetime.now().date(), " at ",data["CurrentTime"], " at ", datetime.now().time().strftime("%H:%M:%S.%f")[:8],"----------------\n ")
        update_autoscaling_group(autoscaling,data)
        print("\n",data)
    #print(env)