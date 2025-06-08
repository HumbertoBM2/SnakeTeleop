#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist
import sys, termios, tty

class OneShotTeleop(Node):
    def __init__(self):
        super().__init__('oneshot_teleop_snake')
        self.pub = self.create_publisher(Twist, '/cmd_vel', 10)
        print("Pulsar: W (adelante), S (atrás), A (giro izq), D (giro der), Ctrl-C para salir.")

    def run(self):
        settings = termios.tcgetattr(sys.stdin)
        try:
            while rclpy.ok():
                tty.setraw(sys.stdin.fileno())
                key = sys.stdin.read(1)
                termios.tcsetattr(sys.stdin, termios.TCSADRAIN, settings)

                twist = Twist()
                if key.lower() == 'w':
                    twist.linear.x =  1.0
                elif key.lower() == 's':
                    twist.linear.x = -1.0
                elif key.lower() == 'a':
                    twist.angular.z =  1.0
                elif key.lower() == 'd':
                    twist.angular.z = -1.0
                else:
                    twist.linear.x  = 0.0
                    twist.angular.z = 0.0

                # Imprime la tecla y lo que se publica
                self.get_logger().info(f'Tecla: {repr(key)} → lin.x={twist.linear.x}, ang.z={twist.angular.z}')

                # envío único del comando
                self.pub.publish(twist)

        except KeyboardInterrupt:
            pass
        finally:
            termios.tcsetattr(sys.stdin, termios.TCSADRAIN, settings)
            rclpy.shutdown()

def main(args=None):
    rclpy.init(args=args)
    node = OneShotTeleop()
    node.run()

if __name__ == '__main__':
    main()
