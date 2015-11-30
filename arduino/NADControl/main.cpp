#include <Arduino.h>
#include <Ethernet.h>

//TODO: disable interrupts during transmission

inline void set_pulse(void) __attribute__((always_inline));
inline void set_flat(void) __attribute__((always_inline));
inline void send_one(void) __attribute__((always_inline));
inline void send_zero(void) __attribute__((always_inline));

void set_pulse(void)
{
	PORTB &= ~_BV(PORTB0);
}

void set_flat(void)
{
	PORTB |= _BV(PORTB0);
}

void send_one(void)
{
	set_pulse();
	_delay_us(560);
	set_flat();
	_delay_us(1690);
}

void send_zero(void)
{
	set_pulse();
	_delay_us(560);
	set_flat();
	_delay_us(560);
}

void send_byte(int b)
{
	int i;
	for (i = 0; i < 8; i ++) {
		if (b & (1 << i))
			send_one();
		else
			send_zero();
	}
}

static void send_command(int c)
{
	/* send preamble */
	set_pulse();
	_delay_us(9000);
	set_flat();
	_delay_us(4500);
	
	/* send address */
	send_one();
	send_one();
	send_one();
	send_zero();
	send_zero();
	send_zero();
	send_zero();
	send_one();

	send_zero();
	send_zero();
	send_one();
	send_one();
	send_one();
	send_one();
	send_one();
	send_zero();
	
	/* send command */
	send_byte(c);
	send_byte(~c);
	
	/* send terminator */
	set_pulse();
	_delay_us(560);
	set_flat();
	_delay_us(42020);
}

byte mac[] = { 0xDE, 0xAD, 0xEF, 0xBE, 0xED, 0xFE };
IPAddress manual_ip(10, 0, 1, 178);
EthernetServer server(80);
EthernetUDP udp;
char broadcast_buffer[UDP_TX_PACKET_MAX_SIZE];

#define BROADCAST_PORT		8839

void setup()
{
	digitalWrite(SS, HIGH);
	
	DDRB |= _BV(DDB0);
	
	set_flat();
	
	if (Ethernet.begin(mac) == 0)
	{
		Ethernet.begin(mac, manual_ip);
	}
	
	_delay_ms(1000);
	
	server.begin();
	
	udp.begin(BROADCAST_PORT);
}

void loop()
{
	int packet_size = udp.parsePacket();
	if (packet_size > 0)
	{
		int num_read = udp.read(broadcast_buffer, sizeof(broadcast_buffer));
		if (num_read >= 1)
		{
			udp.beginPacket(udp.remoteIP(), udp.remotePort());
			udp.println("OK");
			udp.endPacket();
		}
	}
	
	EthernetClient client = server.available();
	if (client)
	{
		enum {
			ParseGet,
			ParseReq,
			ParseSkip,
			ParseCrlf,
			ParseEnd
		} state = ParseGet;
		
		int command = 0;
		
		while (state < ParseEnd && client.connected())
		{
			if (client.available())
			{
				char c = client.read();
				switch (state)
				{
					case ParseGet:
						if (c == ' ')
							state = ParseReq;
						break;
					case ParseReq:
						if (c != '/')
						{
							if (c >= '0' && c <= '9')
								command = command * 10 + c - '0';
							else
								state = ParseSkip;
						}
						break;
					case ParseSkip:
						if (c == '\n')
							state = ParseCrlf;
						break;
					case ParseCrlf:
						if (c == '\n')
							state = ParseEnd;
						else
						if (c != '\r')
							state = ParseSkip;
						break;
					default:
						state = ParseEnd;
				}
			}
		}
		
		if (command > 0)
		{
			send_command(command);
			client.println("HTTP/1.1 302 Found");
			client.println("Location: /");
			client.println();
		}
		else
		{
			client.println("HTTP/1.1 200 OK");
			client.println("Content-Type: text/html");
			client.println("Connection: close");
			client.println();
			client.println("<!DOCTYPE HTML>");
			client.println("<html><body>OK</body></html>");
		}
	
		client.stop();
	}
}
