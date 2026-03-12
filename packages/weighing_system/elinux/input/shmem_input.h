#ifndef SHMEM_INPUT_H
#define SHMEM_INPUT_H

#include "input_source.h"
#include <thread>
#include <atomic>
#include <cstdint>

namespace weighing
{

	struct ShmemConfig
	{
		std::string shm_path = "/dev/mem"; // 改为 /dev/mem 物理地址映射
		int channels = 2;
		int poll_interval_us = 500;
	};

	class ShmemInput : public InputSource
	{
	public:
		ShmemInput();
		~ShmemInput() override;

		// 禁止拷贝（mmap 资源不可共享）
		ShmemInput(const ShmemInput &) = delete;
		ShmemInput &operator=(const ShmemInput &) = delete;

		bool Initialize(const std::string &config_path) override;
		bool Start() override;
		void Stop() override;
		bool IsRunning() const override { return running_.load(); }
		InputMode GetMode() const override { return InputMode::kSharedMemory; }
		int GetChannelCount() const override { return config_.channels; }

	private:
		void PollTask();
		bool ParseConfig(const std::string &config_path);
		void Cleanup();

		ShmemConfig config_;
		std::thread poll_thread_;
		std::atomic<bool> running_{false};

		// --- mmap 资源管理（参照 ShmReader） ---
		void *map_base_ = nullptr;				   ///< mmap 返回的原始基地址
		size_t map_size_ = 0;					   ///< mmap 映射的总大小（页对齐后）
		int shm_fd_ = -1;						   ///< /dev/mem 文件描述符
		volatile ShmemAdcData *shm_ptr_ = nullptr; ///< 指向实际共享内存结构的指针

		uint32_t last_sequence_ = 0;
	};

} // namespace weighing

#endif // SHMEM_INPUT_H