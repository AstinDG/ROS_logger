# ROS_logger
Simple logging via Telegram for routerOS systems

### Simple install

1. Download project
2. Insert your Telegram bot token and chat ID into **botToken** and **chatId** fields
3. Fill search key words into **foundLogs** field
4. Wrire keywords that should be marked message as good at **resolvedMessages** field
5. Wirite **ignoreMessages** write ignore Messages if required or leave a blank line (**""**)
6. Create shedule at System -> Sheduler named as **scheduleName** filed value
7. Enter the edited script code into the scheduler or create a separate script to run from it
8. Enjoy informing via telegram from your routerOS system :)
 ![ROS logger example](/ros_logger_example.png)