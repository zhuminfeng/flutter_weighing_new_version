#include "shmem_input.h"
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <cstring>
#include <ctime>
#include <cstdio>
#include <cerrno>

namespace weighing
{

	ShmemInput::ShmemInput() {}

	ShmemInput::~ShmemInput()
	{
		Stop();
		Cleanup();
	}

	bool ShmemInput::ParseConfig(const std::string &config_path)
	{
		// TODO: 从 JSON 解析配置
		// 目前使用默认值，实际由 SystemInitializer 传入
		config_.shm_path = "/dev/mem";
		config_.channels = 2;
		config_.poll_interval_us = 500;
		return true;
	}

	bool ShmemInput::Initialize(const std::string &config_path)
	{
		ParseConfig(config_path);

		// =====================================================================
		// 1. 打开 /dev/mem（参照 ShmReader::init）
		// =====================================================================
		shm_fd_ = open(config_.shm_path.c_str(), O_RDWR | O_SYNC);
		if (shm_fd_ < 0)
		{
			fprintf(stderr, "ShmemInput: Failed to open %s. Error: %s\n",
					config_.shm_path.c_str(), strerror(errno));
			return false;
		}

		// =====================================================================
		// 2. 页对齐 mmap（参照 ShmReader::init）
		//    - 物理地址 SHM_PHY_BASE_ADDR 可能不在页边界上
		//    - 需要向下对齐到页边界，再加上偏移量定位实际结构体
		// =====================================================================
		long page_size = sysconf(_SC_PAGESIZE);
		if (page_size <= 0)
			page_size = 4096;

		size_t map_size = sizeof(ShmemAdcData);
		size_t aligned_size = ((map_size + page_size - 1) / page_size) * page_size;

		off_t aligned_addr = (SHM_PHY_BASE_ADDR / page_size) * page_size;
		off_t offset = SHM_PHY_BASE_ADDR - aligned_addr;

		// 额外映射量：如果物理地址不在页边界，需要多映射一页以覆盖完整结构体
		size_t total_map_size = aligned_size + static_cast<size_t>(offset);

		void *map = mmap(NULL, total_map_size, PROT_READ | PROT_WRITE,
						 MAP_SHARED, shm_fd_, aligned_addr);
		if (map == MAP_FAILED)
		{
			fprintf(stderr, "ShmemInput: mmap failed. Error: %s\n", strerror(errno));
			close(shm_fd_);
			shm_fd_ = -1;
			return false;
		}

		map_base_ = map;
		map_size_ = total_map_size;
		shm_ptr_ = reinterpret_cast<volatile ShmemAdcData *>(
			static_cast<uint8_t *>(map) + offset);

		// =====================================================================
		// 3. 验证 Magic Number
		// =====================================================================
		volatile uint32_t test_magic = shm_ptr_->magic;
		if (test_magic != SHMEM_MAGIC)
		{
			fprintf(stderr,
					"ShmemInput: Magic number mismatch! Expected 0x%08X, got 0x%08X\n",
					SHMEM_MAGIC, test_magic);
			// 不返回 false —— 可能 MCU 尚未启动，允许后续重试
		}
		else
		{
			printf("ShmemInput: Magic number verified (0x%08X).\n", test_magic);
		}

		printf("ShmemInput: Initialized (path=%s, ch=%d, poll=%dus)\n",
			   config_.shm_path.c_str(), config_.channels, config_.poll_interval_us);
		return true;
	}

	bool ShmemInput::Start()
	{
		if (running_.load())
			return true;

		if (!shm_ptr_)
		{
			fprintf(stderr, "ShmemInput: Not initialized\n");
			return false;
		}

		running_.store(true);
		poll_thread_ = std::thread(&ShmemInput::PollTask, this);
		printf("ShmemInput: Started\n");
		return true;
	}

	void ShmemInput::Stop()
	{
		running_.store(false);
		if (poll_thread_.joinable())
		{
			poll_thread_.join();
		}
		printf("ShmemInput: Stopped\n");
	}

	// =========================================================================
	// 资源清理（参照 ShmReader::cleanup）
	// =========================================================================
	void ShmemInput::Cleanup()
	{
		if (map_base_ && map_base_ != MAP_FAILED)
		{
			munmap(map_base_, map_size_);
			map_base_ = nullptr;
		}
		if (shm_fd_ >= 0)
		{
			close(shm_fd_);
			shm_fd_ = -1;
		}
		shm_ptr_ = nullptr;
	}

	// =========================================================================
	// CRC32 校验（业务逻辑不变）
	// =========================================================================
	static uint32_t crc32_compute(const void *data, size_t len)
	{
		const uint8_t *buf = static_cast<const uint8_t *>(data);
		uint32_t crc = 0xFFFFFFFF;
		for (size_t i = 0; i < len; i++)
		{
			crc ^= buf[i];
			for (int j = 0; j < 8; j++)
			{
				crc = (crc >> 1) ^ (0xEDB88320 & (-(crc & 1)));
			}
		}
		return ~crc;
	}

	// =========================================================================
	// 轮询任务（业务逻辑不变，仅移除对 MAP_FAILED 的冗余检查）
	// =========================================================================
	void ShmemInput::PollTask()
	{
		struct timespec ts;
		ts.tv_sec = 0;
		ts.tv_nsec = config_.poll_interval_us * 1000L;

		while (running_.load(std::memory_order_acquire))
		{
			if (!shm_ptr_)
			{
				nanosleep(&ts, nullptr);
				continue;
			}

			const volatile ShmemAdcData *shm = shm_ptr_;

			uint32_t seq1 = shm->sequence;
			__sync_synchronize();

			if (shm->magic != SHMEM_MAGIC)
			{
				nanosleep(&ts, nullptr);
				continue;
			}

			ShmemAdcData local;
			memcpy(&local,
				   const_cast<const void *>(
					   static_cast<volatile void *>(
						   const_cast<volatile ShmemAdcData *>(shm))),
				   sizeof(ShmemAdcData));

			__sync_synchronize();
			uint32_t seq2 = shm->sequence;

			if (seq1 != seq2)
			{
				nanosleep(&ts, nullptr);
				continue;
			}

			if (seq1 == last_sequence_)
			{
				nanosleep(&ts, nullptr);
				continue;
			}
			last_sequence_ = seq1;

			uint32_t expected_crc = crc32_compute(&local,
												  sizeof(ShmemAdcData) - sizeof(uint32_t));
			if (expected_crc != local.crc32)
			{
				nanosleep(&ts, nullptr);
				continue;
			}

			for (int ch = 0; ch < config_.channels && ch < 2; ch++)
			{
				AdcSample sample;
				sample.raw_value = local.channel[ch].raw_adc;
				sample.status = local.channel[ch].status;
				sample.timestamp_ns = local.timestamp_ns;
				sample.channel_id = static_cast<uint32_t>(ch);

				if (adc_callback_)
				{
					adc_callback_(sample);
				}
			}

			nanosleep(&ts, nullptr);
		}
	}

} // namespace weighing