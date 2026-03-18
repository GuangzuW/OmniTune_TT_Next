#include "AudioPlayer.h"
#include <iostream>
#include <thread>
#include <chrono>

int main() {
    std::cout << "Testing AudioPlayer for memory leaks..." << std::endl;
    {
        AudioPlayer player;
        // Basic init and destroy
    }
    std::cout << "Test completed." << std::endl;
    return 0;
}
