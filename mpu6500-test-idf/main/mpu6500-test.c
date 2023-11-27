/* i2c - Simple example

   Simple I2C example that shows how to initialize I2C
   as well as reading and writing from and to registers for a sensor connected over I2C.

   The sensor used in this example is a MPU6500 inertial measurement unit.

   For other examples please check:
   https://github.com/espressif/esp-idf/tree/master/examples

   See README.md file to get detailed usage of this example.

   This example code is in the Public Domain (or CC0 licensed, at your option.)

   Unless required by applicable law or agreed to in writing, this
   software is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
   CONDITIONS OF ANY KIND, either express or implied.
*/
#include <stdio.h>
#include "esp_log.h"
#include "esp_timer.h"
#include "driver/gpio.h"
#include "mpu6500.h"

static const char *TAG = "mpu6500-test";

#define BUTTON1 19

void app_main(void)
{
    acc_data_t accData;

    gpio_set_direction(BUTTON1, GPIO_MODE_INPUT);
    gpio_set_pull_mode(BUTTON1, GPIO_PULLUP_ONLY);

    ESP_ERROR_CHECK(mpu6500_i2c_init());
    ESP_LOGI(TAG, "I2C initialized successfully");

    /* Read the MPU6500 WHO_AM_I register, on power up the register should have the value 0x71 */
    // ESP_ERROR_CHECK(mpu6500_register_read(MPU6500_WHO_AM_I_REG_ADDR, data, 1));
    // ESP_LOGI(TAG, "WHO_AM_I = %X", data[0]);

    /* Demonstrate writing by reseting the MPU6500 */
    // ESP_ERROR_CHECK(mpu6500_register_write_byte(MPU6500_PWR_MGMT_1_REG_ADDR, 1 << MPU6500_RESET_BIT));

    printf("Start collection\n");
    
    while(true) {
        ESP_ERROR_CHECK(mpu6500_get_acc(&accData));

        // printf("%lld ", esp_timer_get_time() / 1000);
        printf("%+f %+f %+f %d\n", accData.accX, accData.accY, accData.accZ, !gpio_get_level(BUTTON1));
        vTaskDelay(pdMS_TO_TICKS(3));
    }

    ESP_ERROR_CHECK(i2c_driver_delete(I2C_MASTER_NUM));
}
