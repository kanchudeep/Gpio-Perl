# Basic Perl module to interface with GPIO devices with Raspberry Pi and similar SBCs
package Gpio;

use strict;
use warnings;

use Exporter 'import';

our @EXPORT = qw(HIGH LOW IN OUT &gpio_is_exported &gpio_export &gpio_unexport &gpio_read &gpio_write &gpio_toggle);

use constant {
	GPIO_BASE => "/sys/class/gpio/", # Base path
	HIGH => "1",
	LOW => "0",
	IN => "in",
	OUT => "out"
};

# Subroutine to read complete text of a file - returns undefined on errors
sub file_read($) {
	my $file = shift();
	if (open(my $fh, "<", $file)) {
		my $data = do {
			local $/ = undef;	
			<$fh>;
		};
		return $data;
	} else {
		warn("Cannot open file '$file': $!");
		return;
	}
}

# Subroutine to write to a file
sub file_write($$) {
	my ($file, $data) = @_;
	if (open(my $fh, ">", $file)) {
		print $fh $data;
		close($fh);
		return 1;
	} else {
		warn("Cannot write to file '$file': $!");
		return 0;
	}
}

# Subroutine to check sysfs GPIO support
sub gpio_sysfs_check() {
	if (-d GPIO_BASE) {
		return 1;
	}
	warn("No support for sysfs interface for GPIO dected");
	return 0;
}

# Subroutine to check if GPIO pin number is valid (positive integer)
sub gpio_is_valid($) {# Check valid pin
	if (gpio_sysfs_check()) {
		my $pin = shift();
		if ($pin =~ /^\d+$/) {
			return 1;
		}
		warn("Invalid pin: '$pin'");
	}
	return 0;
}

# Subroutine to check if GPIO pin is valid and already exported
sub gpio_is_exported($) {
	my $pin = shift();
	if (gpio_is_valid($pin)) {
		if (-d GPIO_BASE . "gpio$pin/") {
			return 1;
		}
	}
	return 0;
}

# Subroutine to export a GPIO
sub gpio_export($$) {
	my ($pin, $mode) = @_;
	# Check valid mode
	if ($mode eq IN || $mode eq OUT) {
		# Check valid pin
		if (gpio_is_valid($pin)) {
			if (!-d GPIO_BASE . "gpio$pin/") {
				file_write(GPIO_BASE . "export", "$pin\n") or return 0;
				system("udevadm", "settle");
				sleep(1);
				return file_write(GPIO_BASE . "gpio$pin/direction", $mode);
			} else {
				warn("GPIO $pin already exported");
			}
		}
	} else {
		warn("Invalid mode: '$mode'");
	}
	return 0;
}

# Subroutine to unexport GPIO
sub gpio_unexport($) {
	my $pin = shift();
	if (gpio_is_exported($pin)) {
		return file_write(GPIO_BASE . "unexport", "$pin\n");
	}
	return 0;
}

# Subroutine to read a GPIO - returns undefined on errors
sub gpio_read($) {
	my $pin = shift();
	if (gpio_is_exported($pin)) {
		my $value = file_read(GPIO_BASE . "gpio$pin/value");
		if (defined($value)) {
			chomp($value);
			return $value;
		}
	}
	return;
}

# Subroutine to write to a GPIO - returns '1' for success and '0' for errors
sub gpio_write($$) {
	my ($pin, $value) = @_;
	if (gpio_is_exported($pin)) {
		my $direction = file_read(GPIO_BASE . "gpio$pin/direction");
		chomp($direction);
		if ($direction ne OUT) {
			warn("GPIO $pin is not in " . OUT . " mode");
			return 0;
		}
		return file_write(GPIO_BASE . "gpio$pin/value", $value)
	}
	return 0;
}

# Subroutine to toggle
sub gpio_toggle($) {
	my $pin = shift();
	if (gpio_is_exported($pin)) {
		my $value = gpio_read($pin);
		if ($value eq HIGH) {
			return gpio_write($pin, LOW);
		} elsif ($value eq LOW) {
			return gpio_write($pin, HIGH);
		}
	}
	return 0;
}

1;

__END__
